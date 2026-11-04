import AppKit
import ObjectiveC
import SwiftUI

/// Wraps the SwiftUI hosting view in `NSGlassEffectView` so Liquid Glass samples the desktop wallpaper.
struct WindowWallpaperGlass: NSViewRepresentable {
    func makeNSView(context: Context) -> GlassInstallerView {
        GlassInstallerView()
    }

    func updateNSView(_ nsView: GlassInstallerView, context: Context) {
        nsView.scheduleInstall()
    }
}

private var gdmGlassInstalledKey: UInt8 = 0

final class GlassInstallerView: NSView {
    private var didInstall = false
    private var resizeObserver: NSObjectProtocol?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
        layer?.isOpaque = false
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let resizeObserver {
            NotificationCenter.default.removeObserver(resizeObserver)
        }
    }

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        observeResize()
        scheduleInstall()
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        scheduleInstall()
    }

    func scheduleInstall() {
        if window.flatMap(Self.isInstalled(on:)) == true {
            didInstall = true
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.installIfNeeded()
        }
    }

    func installIfNeeded() {
        guard let window else { return }
        if Self.isInstalled(on: window) || window.contentView is NSGlassEffectView {
            didInstall = true
            Self.markInstalled(window)
            return
        }
        // Tiling / live resize recreates chrome; swapping contentView in that pass crashes.
        if window.inLiveResize { return }

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.styleMask.insert(.fullSizeContentView)
        window.hasShadow = true
        window.alphaValue = 1

        guard let hosting = window.contentView, !(hosting is NSGlassEffectView) else {
            didInstall = true
            Self.markInstalled(window)
            return
        }
        makeClear(hosting)

        let glass = NSGlassEffectView()
        glass.style = .clear
        glass.tintColor = nil
        glass.cornerRadius = 0
        glass.frame = hosting.frame
        glass.autoresizingMask = [.width, .height]

        window.contentView = glass
        glass.contentView = hosting
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = glass.bounds

        makeClear(hosting)
        makeClear(glass)
        clearAncestors(of: glass)
        didInstall = true
        Self.markInstalled(window)
    }

    private func observeResize() {
        guard resizeObserver == nil else { return }
        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self, note.object as? NSWindow === self.window else { return }
            self.scheduleInstall()
        }
    }

    private static func isInstalled(on window: NSWindow) -> Bool {
        objc_getAssociatedObject(window, &gdmGlassInstalledKey) as? Bool == true
    }

    private static func markInstalled(_ window: NSWindow) {
        objc_setAssociatedObject(window, &gdmGlassInstalledKey, true, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

    private func makeClear(_ view: NSView?) {
        guard let view else { return }
        view.wantsLayer = true
        view.layer?.isOpaque = false
        view.layer?.backgroundColor = .clear
    }

    private func clearAncestors(of view: NSView) {
        var node: NSView? = view.superview
        while let current = node {
            makeClear(current)
            if let fx = current as? NSVisualEffectView {
                fx.blendingMode = .behindWindow
                fx.material = .underWindowBackground
                fx.state = .active
            }
            node = current.superview
        }
    }
}
