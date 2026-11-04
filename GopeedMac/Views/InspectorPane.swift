import SwiftUI

struct InspectorPane: View {
    @EnvironmentObject private var store: DownloadStore

    var body: some View {
        Group {
            if let task = store.selectedTask {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.spaceLG) {
                            header(task)
                            identity(task)
                            status(task)
                            chunks(task)
                            meta(task)
                            SpeedChart(samples: store.speedHistory[task.id] ?? [], current: task.speed)
                            metrics(task)
                        }
                        .padding(.horizontal, Theme.spaceXL)
                        .padding(.top, Theme.spaceXL)
                        .padding(.bottom, Theme.spaceMD)
                    }
                    .scrollIndicators(.never)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    controls(task)
                        .padding(.horizontal, Theme.spaceXL)
                        .padding(.bottom, Theme.spaceXL)
                        .padding(.top, Theme.spaceSM)
                }
            } else {
                VStack(spacing: Theme.spaceMD) {
                    Image(systemName: "sidebar.right")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.tertiary)
                    Text("Select a download")
                        .foregroundStyle(Theme.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func header(_ task: DownloadTask) -> some View {
        HStack {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                    store.inspectorCollapsed = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Inspector")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 8)
                .padding(.trailing, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(FullAreaButtonStyle())
            .help("Hide Inspector")
            Spacer()
        }
    }

    private func identity(_ task: DownloadTask) -> some View {
        let kind = FileKind.kind(for: task.displayName)
        return HStack(spacing: Theme.spaceMD) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(kind.color.opacity(0.2))
                Image(systemName: kind.symbol)
                    .foregroundStyle(kind.color)
            }
            .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.spaceXS) {
                    Text(task.displayName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                    Button {
                        store.openURL(task)
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .foregroundStyle(Theme.secondary)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FullAreaButtonStyle())
                }
                HStack(spacing: Theme.spaceXS) {
                    Circle().fill(statusColor(task)).frame(width: 7, height: 7)
                    Text("\(task.status.title)  •  \(task.percentText)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.secondary)
                }
            }
            Spacer()
        }
    }

    private func status(_ task: DownloadTask) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * task.fraction)
            }
        }
        .frame(height: 8)
    }

    private func chunks(_ task: DownloadTask) -> some View {
        let connections = store.statsByID[task.id]?.connections ?? []
        let total = max(connections.count, task.connections, 1)
        let completed: Int = {
            if !connections.isEmpty {
                return connections.filter { $0.completed == true }.count
            }
            return Int((task.fraction * Double(256)).rounded())
        }()
        let visualTotal = connections.isEmpty ? 256 : total
        return ChunkGrid(completed: connections.isEmpty ? completed : completed, total: visualTotal)
    }

    private func meta(_ task: DownloadTask) -> some View {
        VStack(spacing: Theme.spaceMD) {
            metaRow("location", title: "Source URL", value: task.meta?.req?.url ?? "—")
            metaRow("internaldrive", title: "File Size", value: ByteFormat.string(task.totalSize))
            metaRow("clock", title: "Added", value: addedText(task))
            HStack(alignment: .top) {
                metaIcon("location")
                Text("Location")
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 92, alignment: .leading)
                Text(task.fileURL?.path ?? task.meta?.opts?.path ?? "—")
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                Spacer()
                Button { store.reveal(task) } label: {
                    Image(systemName: "folder")
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(FullAreaButtonStyle())
            }
            .font(.system(size: 12))
        }
    }

    private func metrics(_ task: DownloadTask) -> some View {
        VStack(spacing: Theme.spaceMD) {
            HStack(spacing: Theme.spaceMD) {
                metric("Time Elapsed", ByteFormat.duration(task.elapsed))
                metric("Time Remaining", task.remaining.map(ByteFormat.duration) ?? "--:--")
            }
            HStack(spacing: Theme.spaceMD) {
                metric("Current Speed", ByteFormat.speed(task.speed))
                metric("Average Speed", ByteFormat.speed(task.averageSpeed))
            }
            HStack(spacing: Theme.spaceMD) {
                HStack {
                    Text("Priority")
                        .foregroundStyle(Theme.secondary)
                    Spacer()
                    Text("High")
                        .padding(.horizontal, Theme.spaceMD)
                        .padding(.vertical, Theme.spaceXS)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                        .foregroundStyle(Theme.tertiary)
                }
                .padding(Theme.spaceMD)
                .liquidGlass(cornerRadius: 16)

                HStack(spacing: Theme.spaceSM) {
                    Text("Connections")
                        .foregroundStyle(Theme.secondary)
                    Button {
                        Task { await store.setConnections(max(1, store.connectionsDraft - 1), for: task) }
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FullAreaButtonStyle())
                    Slider(
                        value: Binding(
                            get: { Double(store.connectionsDraft) },
                            set: { store.connectionsDraft = Int($0) }
                        ),
                        in: 1...32,
                        step: 1
                    ) { editing in
                        if !editing {
                            Task { await store.setConnections(store.connectionsDraft, for: task) }
                        }
                    }
                    .tint(Theme.accent)
                    Button {
                        Task { await store.setConnections(min(32, store.connectionsDraft + 1), for: task) }
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(FullAreaButtonStyle())
                    Text("\(store.connectionsDraft) / 32")
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(Theme.spaceMD)
                .liquidGlass(cornerRadius: 16)
            }
            .font(.system(size: 12))
        }
    }

    private func controls(_ task: DownloadTask) -> some View {
        EqualWidthHStack(spacing: 12) {
            if task.status == .running || task.status == .wait || task.status == .ready {
                inspectorAction("Pause", symbol: "pause.fill", kind: .prominent) {
                    Task { await store.pause(task) }
                }
            } else {
                inspectorAction("Resume", symbol: "play.fill", kind: .prominent) {
                    Task { await store.resume(task) }
                }
            }

            inspectorAction("Reveal", symbol: "folder", kind: .regular) {
                store.reveal(task)
            }

            inspectorAction("Cancel", symbol: "xmark", kind: .danger) {
                Task { await store.delete(task, removeFiles: true) }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: Theme.toolbarHeight)
    }

    private func inspectorAction(_ title: String, symbol: String, kind: CapsuleActionButtonStyle.Kind, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
        }
        .buttonStyle(CapsuleActionButtonStyle(kind: kind, fillWidth: true))
        .frame(maxWidth: .infinity, minHeight: Theme.toolbarHeight, maxHeight: Theme.toolbarHeight)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spaceMD)
        .liquidGlass(cornerRadius: 16)
    }

    private func metaRow(_ symbol: String, title: String, value: String) -> some View {
        HStack(alignment: .top) {
            metaIcon(symbol)
            Text(title)
                .foregroundStyle(Theme.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value)
                .foregroundStyle(.white)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.system(size: 12))
    }

    private func metaIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .foregroundStyle(Theme.secondary)
            .frame(width: 16)
    }

    private static let addedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func addedText(_ task: DownloadTask) -> String {
        guard let date = task.createdAt else { return "—" }
        return Self.addedFormatter.string(from: date)
    }

    private func statusColor(_ task: DownloadTask) -> Color {
        switch task.status {
        case .running: return Theme.accent
        case .done: return Theme.success
        case .error: return .orange
        default: return Theme.tertiary
        }
    }
}
