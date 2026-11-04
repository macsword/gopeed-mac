import SwiftUI

struct DownloadListPane: View {
    @EnvironmentObject private var store: DownloadStore

    var body: some View {
        GeometryReader { geo in
            let useGrid = geo.size.width >= Theme.listGridBreakpoint
            let columns = gridColumns(for: geo.size.width, count: store.visibleTasks.count)
            VStack(spacing: 0) {
                HStack {
                    Label("Downloads", systemImage: "arrow.down")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolRenderingMode(.hierarchical)
                    Spacer()
                    Text("\(store.visibleTasks.count) Total")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.secondary)
                }
                .padding(.horizontal, Theme.spaceLG)
                .padding(.top, Theme.spaceMD)
                .padding(.bottom, Theme.spaceLG)

                ScrollView {
                    Group {
                        if useGrid {
                            LazyVGrid(columns: columns, spacing: Theme.spaceSM) {
                                cards(layout: .grid)
                            }
                        } else {
                            LazyVStack(spacing: Theme.spaceSM) {
                                cards(layout: .list)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spaceMD)
                    .padding(.top, Theme.spaceSM)
                    .padding(.bottom, Theme.spaceSM)
                }
                .scrollIndicators(.never)
                .scrollClipFade()

                HStack(spacing: 12) {
                    Button {
                        store.showingAdd = true
                    } label: {
                        Label("Add Download...", systemImage: "plus")
                    }
                    .buttonStyle(CapsuleActionButtonStyle())
                    .focusable(false)
                    Button {
                        Task { await store.pasteFromClipboard() }
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: Theme.iconSize, height: Theme.iconSize)
                    }
                    .buttonStyle(CapsuleActionButtonStyle(kind: .icon))
                    .help("Paste link from clipboard")
                    .focusable(false)
                    Spacer()
                    Button {
                        store.showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .resizable()
                            .scaledToFit()
                            .frame(width: Theme.settingsIconSize, height: Theme.settingsIconSize)
                    }
                    .buttonStyle(CapsuleActionButtonStyle(kind: .icon))
                    .help("Settings")
                    .focusable(false)
                }
                .padding(.horizontal, Theme.spaceLG)
                .padding(.vertical, Theme.spaceLG)
            }
        }
        .onAppear {
            if store.selection == nil {
                store.selection = store.visibleTasks.first?.id
            }
        }
    }

    private func gridColumns(for width: CGFloat, count: Int) -> [GridItem] {
        let minTile: CGFloat = 260
        let spacing = Theme.spaceSM
        let inner = max(minTile, width - Theme.spaceMD * 2)
        let maxCols = max(1, Int((inner + spacing) / (minTile + spacing)))
        let cols = min(maxCols, max(1, count))
        return Array(repeating: GridItem(.flexible(), spacing: spacing, alignment: .top), count: cols)
    }

    @ViewBuilder
    private func cards(layout: DownloadCard.Layout) -> some View {
        ForEach(store.visibleTasks) { task in
            DownloadCard(
                task: task,
                selected: store.selection == task.id,
                layout: layout,
                actionsOpen: store.openCardActions == task.id,
                onSelect: {
                    store.selection = task.id
                },
                onSetActionsOpen: { open in
                    if open {
                        store.openCardActions = task.id
                    } else if store.openCardActions == task.id {
                        store.openCardActions = nil
                    }
                },
                onPause: { Task { await store.pause(task) } },
                onResume: { Task { await store.resume(task) } },
                onReveal: { store.reveal(task) },
                onRemove: { Task { await store.delete(task, removeFiles: false) } },
                onDelete: { Task { await store.delete(task, removeFiles: true) } }
            )
            .equatable()
            .focusable(false)
        }
    }
}
