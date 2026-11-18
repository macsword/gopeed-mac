import AppKit
import SwiftUI

@main
struct GopeedMacApp: App {
    @StateObject private var store = DownloadStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 560, minHeight: 480)
                .onAppear { store.start() }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.stop()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .windowResizability(.contentMinSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1380, height: 760)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Download…") {
                    NotificationCenter.default.post(name: .gopeedNewDownload, object: nil)
                }
                .keyboardShortcut("n")
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    store.showingSettings = true
                }
                .keyboardShortcut(",")
            }
            CommandMenu("Downloads") {
                Button("Select All") {
                    store.selectAllVisible()
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .disabled(store.visibleTasks.isEmpty)
                Button("Deselect") {
                    store.collapseSelection()
                }
                .disabled(!store.selectionState.isMultiple)
                Divider()
                Button("Pause Selected") {
                    Task { await store.pauseSelected() }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .disabled(!store.canPauseSelected)
                Button("Resume Selected") {
                    Task { await store.resumeSelected() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
                .disabled(!store.canResumeSelected)
                Button("Reveal in Finder") {
                    store.revealSelected()
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(store.selectedTasks.isEmpty)
                Divider()
                Button("Remove from List") {
                    Task { await store.deleteSelected(removeFiles: false) }
                }
                .keyboardShortcut(.delete, modifiers: [.command])
                .disabled(store.selectedTasks.isEmpty)
                Button("Delete Files") {
                    Task { await store.deleteSelected(removeFiles: true) }
                }
                .keyboardShortcut(.delete, modifiers: [.command, .option])
                .disabled(store.selectedTasks.isEmpty)
            }
        }
    }
}

extension Notification.Name {
    static let gopeedNewDownload = Notification.Name("gopeed.newDownload")
    static let gdmDroppedLinks = Notification.Name("gdm.droppedLinks")
    static let gdmDropTargeted = Notification.Name("gdm.dropTargeted")
}
