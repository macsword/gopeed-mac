import SwiftUI

struct DownloadListPane: View {
    @EnvironmentObject private var store: DownloadStore
    @FocusState private var focusedTask: DownloadTask.ID?

    var body: some View {
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
                LazyVStack(spacing: Theme.spaceSM) {
                    ForEach(store.visibleTasks) { task in
                        DownloadCard(
                            task: task,
                            selected: store.selection == task.id,
                            onSelect: {
                                store.selection = task.id
                                focusedTask = task.id
                            },
                            onPause: { Task { await store.pause(task) } },
                            onResume: { Task { await store.resume(task) } },
                            onReveal: { store.reveal(task) },
                            onRemove: { Task { await store.delete(task, removeFiles: false) } }
                        )
                        .equatable()
                        .focusable()
                        .focused($focusedTask, equals: task.id)
                        .focusEffectDisabled()
                    }
                }
                .padding(.horizontal, Theme.spaceMD)
            }
            .focusSection()
            .defaultFocus($focusedTask, store.visibleTasks.first?.id)

            HStack {
                Button {
                    store.showingAdd = true
                } label: {
                    Label("Add Download...", systemImage: "plus")
                }
                .buttonStyle(CapsuleActionButtonStyle())
                .focusable(false)
                Spacer()
                Button {
                    store.showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(CapsuleActionButtonStyle(kind: .icon))
                .help("Settings")
                .focusable(false)
            }
            .padding(.horizontal, Theme.spaceLG)
            .padding(.vertical, Theme.spaceLG)
        }
        .onAppear { focusFirstDownload() }
        .onChange(of: store.visibleTasks.map(\.id)) { _, _ in
            focusFirstDownload()
        }
    }

    private func focusFirstDownload() {
        let first = store.selection ?? store.visibleTasks.first?.id
        guard let first else { return }
        if store.selection == nil {
            store.selection = first
        }
        if focusedTask == nil {
            focusedTask = first
        }
    }
}
