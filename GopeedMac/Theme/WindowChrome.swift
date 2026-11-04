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
        if let window, Self.isInstalled(on: window) {
            didInstall = true
            (window.contentView as? DropRootView)?.prepareForDrops()
            return
        }
        DispatchQueue.main.async { [weak self] in
            self?.installIfNeeded()
        }
    }

    func installIfNeeded() {
        guard let window else { return }
        if Self.isInstalled(on: window) || window.contentView is DropRootView {
            didInstall = true
            Self.markInstalled(window)
            (window.contentView as? DropRootView)?.prepareForDrops()
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

        guard let hosting = window.contentView,
              !(hosting is DropRootView),
              !(hosting is NSGlassEffectView) else {
            didInstall = true
            Self.markInstalled(window)
            (window.contentView as? DropRootView)?.prepareForDrops()
            return
        }
        makeClear(hosting)

        let root = DropRootView(frame: hosting.frame)
        root.autoresizingMask = [.width, .height]

        let glass = NSGlassEffectView(frame: hosting.frame)
        glass.style = .clear
        glass.tintColor = nil
        glass.cornerRadius = 0
        glass.autoresizingMask = [.width, .height]

        window.contentView = root
        root.addSubview(glass)
        glass.frame = root.bounds
        glass.contentView = hosting
        hosting.autoresizingMask = [.width, .height]
        hosting.frame = glass.bounds
        root.prepareForDrops()

        makeClear(hosting)
        makeClear(glass)
        makeClear(root)
        clearAncestors(of: root)
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

/// Window content view that owns drops. Liquid Glass and NSHostingView both register
/// dragged types and return `.none`, which eats Finder/Safari drops before SwiftUI
/// sees them. This view sits above that stack only while a drag is live.
final class DropRootView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = .clear
        registerForDraggedTypes(DropDispatch.types)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { false }

    func prepareForDrops() {
        registerForDraggedTypes(DropDispatch.types)
        for child in subviews {
            DropDispatch.unregisterTree(child)
        }
    }

    override func layout() {
        super.layout()
        for child in subviews {
            child.frame = bounds
            DropDispatch.unregisterTree(child)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if DropDispatch.isLiveDrag {
            return self
        }
        return super.hitTest(point)
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        NotificationCenter.default.post(name: .gdmDropTargeted, object: true)
        return DropDispatch.operation(for: sender)
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        DropDispatch.operation(for: sender)
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        NotificationCenter.default.post(name: .gdmDropTargeted, object: false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        NotificationCenter.default.post(name: .gdmDropTargeted, object: false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return DropDispatch.perform(sender)
    }

    override func concludeDragOperation(_ sender: NSDraggingInfo?) {
        NotificationCenter.default.post(name: .gdmDropTargeted, object: false)
    }
}

private enum DropDispatch {
    static let types: [NSPasteboard.PasteboardType] = [
        .URL,
        .fileURL,
        .string,
        .html,
        .rtf,
        NSPasteboard.PasteboardType("public.url"),
        NSPasteboard.PasteboardType("public.file-url"),
        NSPasteboard.PasteboardType("public.utf8-plain-text"),
        NSPasteboard.PasteboardType("public.plain-text"),
        NSPasteboard.PasteboardType("NSFilenamesPboardType"),
        NSPasteboard.PasteboardType("Apple URL pasteboard type"),
        NSPasteboard.PasteboardType("text/uri-list")
    ]

    static var isLiveDrag: Bool {
        let pasteboard = NSPasteboard(name: .drag)
        let hasDrag = !(pasteboard.types ?? []).isEmpty
            || !(pasteboard.pasteboardItems ?? []).isEmpty
        guard hasDrag, NSEvent.pressedMouseButtons != 0 else { return false }
        if let type = NSApp.currentEvent?.type {
            switch type {
            case .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp:
                return false
            default:
                return true
            }
        }
        return true
    }

    static func operation(for sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingSourceOperationMask.contains(.copy) ? .copy : .generic
    }

    static func perform(_ sender: NSDraggingInfo) -> Bool {
        NotificationCenter.default.post(name: .gdmDropTargeted, object: false)
        let links = DownloadLinkParser.links(from: sender.draggingPasteboard)
        guard !links.isEmpty else { return false }
        NotificationCenter.default.post(name: .gdmDroppedLinks, object: links)
        return true
    }

    static func unregisterTree(_ view: NSView?) {
        guard let view else { return }
        view.unregisterDraggedTypes()
        for child in view.subviews {
            unregisterTree(child)
        }
    }
}
