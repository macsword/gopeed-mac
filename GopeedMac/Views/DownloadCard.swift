import SwiftUI

struct DownloadCard: View, Equatable {
    static func == (lhs: DownloadCard, rhs: DownloadCard) -> Bool {
        lhs.task == rhs.task && lhs.selected == rhs.selected
    }
    let task: DownloadTask
    let selected: Bool
    let onSelect: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void

    @State private var ringHover = false

    private var kind: FileKind { FileKind.kind(for: task.displayName) }

    var body: some View {
        HStack(spacing: Theme.spaceMD) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(kind.color)
                Image(systemName: kind.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: Theme.spaceXS) {
                Text(task.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(sizeLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.secondary)
                HStack(spacing: Theme.spaceXS) {
                    if task.status == .done {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.success)
                        Text("Completed")
                            .foregroundStyle(Theme.success)
                    } else if task.status == .error {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(task.status.title)
                    } else if task.status == .pause {
                        Text(ByteFormat.speed(task.speed))
                        Text("Paused")
                    } else {
                        Text(ByteFormat.speed(task.speed))
                        if let remaining = task.remaining {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(Theme.remaining)
                            Text(ByteFormat.remainingShort(remaining))
                                .foregroundStyle(Theme.remaining)
                        }
                    }
                }
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
            }

            Spacer(minLength: Theme.spaceSM)

            ringButton

            Menu {
                if task.status == .running || task.status == .wait {
                    Button("Pause", action: onPause)
                }
                if task.status == .pause || task.status == .error {
                    Button("Resume", action: onResume)
                }
                Button("Reveal in Finder", action: onReveal)
                Divider()
                Button("Remove from List", role: .destructive, action: onRemove)
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                    .frame(width: 36, height: 44)
                    .background(Color.white.opacity(0.001))
                    .contentShape(Rectangle())
            }
            .buttonStyle(FullAreaButtonStyle())
            .menuIndicator(.hidden)
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.vertical, Theme.spaceXL)
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .onTapGesture(perform: onSelect)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(selected ? Color.white.opacity(0.38) : Theme.hairline, lineWidth: selected ? 1.5 : 1)
        )
        .shadow(color: selected ? Color.white.opacity(0.08) : .clear, radius: 12, y: 2)
        .liquidGlass(
            cornerRadius: Theme.cardRadius,
            tint: selected ? Color.black.opacity(0.22) : Color.black.opacity(0.36)
        )
    }

    private var ringButton: some View {
        Button {
            if canPause { onPause() }
            else if canResume { onResume() }
        } label: {
            CircularProgressRing(
                progress: task.fraction,
                color: ringColor,
                hovering: ringHover && (canPause || canResume),
                hoverSymbol: canPause ? "pause.fill" : (canResume ? "play.fill" : nil)
            )
            .contentShape(Circle())
        }
        .buttonStyle(FullAreaButtonStyle())
        .disabled(!(canPause || canResume))
        .onContinuousHover { phase in
            switch phase {
            case .active: ringHover = true
            case .ended: ringHover = false
            }
        }
        .help(canPause ? "Pause" : (canResume ? "Resume" : task.percentText))
    }

    private var canPause: Bool {
        task.status == .running || task.status == .wait || task.status == .ready
    }

    private var canResume: Bool {
        task.status == .pause || task.status == .error
    }

    private var sizeLine: String {
        if task.totalSize > 0 {
            return "\(ByteFormat.string(task.downloaded)) / \(ByteFormat.string(task.totalSize))  •  \(task.percentText)"
        }
        return "\(ByteFormat.string(task.downloaded))  •  \(task.percentText)"
    }

    private var ringColor: Color {
        if task.status == .done { return Theme.success }
        return kind.color
    }
}
