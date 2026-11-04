import SwiftUI

struct DownloadCard: View, Equatable {
    enum Layout {
        case list
        case grid
    }

    static func == (lhs: DownloadCard, rhs: DownloadCard) -> Bool {
        lhs.task == rhs.task && lhs.selected == rhs.selected && lhs.layout == rhs.layout
    }
    let task: DownloadTask
    let selected: Bool
    var layout: Layout = .list
    let onSelect: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onReveal: () -> Void
    let onRemove: () -> Void
    let onDelete: () -> Void

    @State private var ringHover = false
    @State private var actionsOpen = false

    private var kind: FileKind { FileKind.kind(for: task.displayName) }

    var body: some View {
        Group {
            if layout == .grid {
                gridContent
            } else {
                listContent
            }
        }
        .padding(.horizontal, Theme.spaceLG)
        .padding(.vertical, layout == .grid ? Theme.spaceMD : Theme.spaceXL)
        .padding(.trailing, 44)
        .frame(
            maxWidth: .infinity,
            minHeight: layout == .grid ? Theme.gridCardHeight : 0,
            maxHeight: layout == .grid ? Theme.gridCardHeight : nil,
            alignment: .topLeading
        )
        .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(selected ? Color.white.opacity(0.38) : Theme.hairline, lineWidth: selected ? 1.5 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .shadow(color: selected ? Color.white.opacity(0.08) : .clear, radius: 12, y: 2)
        .liquidGlass(
            cornerRadius: Theme.cardRadius,
            tint: selected ? Color.black.opacity(0.22) : Color.black.opacity(0.36)
        )
        .overlay(alignment: .topTrailing) {
            actionCluster
                .padding(.top, layout == .grid ? Theme.spaceMD : 12)
                .padding(.trailing, Theme.spaceMD)
        }
        .zIndex(actionsOpen ? 2 : 0)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: actionsOpen)
    }

    private var listContent: some View {
        HStack(spacing: Theme.spaceMD) {
            typeBadge
            metaBlock(lineLimit: 1)
            Spacer(minLength: Theme.spaceSM)
            ringButton
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: selectOrClose)
    }

    private var gridContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            typeBadge
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                HStack {
                    Spacer(minLength: 0)
                    ringButton
                    Spacer(minLength: 0)
                }
                Spacer(minLength: 8)
                metaBlock(lineLimit: 2)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: selectOrClose)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func selectOrClose() {
        if actionsOpen {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                actionsOpen = false
            }
        } else {
            onSelect()
        }
    }

    private var typeBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(kind.color)
            Image(systemName: kind.symbol)
                .resizable()
                .scaledToFit()
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .foregroundStyle(.white)
        }
        .frame(width: 52, height: 52)
    }

    private func metaBlock(lineLimit: Int) -> some View {
        VStack(alignment: .leading, spacing: Theme.spaceXS) {
            Text(task.displayName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(lineLimit)
                .frame(height: lineLimit == 2 ? 36 : nil, alignment: .topLeading)
            Text(sizeLine)
                .font(.system(size: 12))
                .foregroundStyle(Theme.secondary)
                .lineLimit(1)
            statusRow
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusRow: some View {
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

    private var actionCluster: some View {
        VStack(spacing: 6) {
            if actionsOpen {
                circleAction("minus", help: "Remove from list", fill: Theme.toolbarFill) {
                    actionsOpen = false
                    onRemove()
                }
                circleAction("folder", help: "Reveal in Finder", fill: Theme.toolbarFill) {
                    actionsOpen = false
                    onReveal()
                }
                circleAction("trash", help: "Delete file", fill: Theme.danger.opacity(0.88)) {
                    actionsOpen = false
                    onDelete()
                }
            } else {
                Button {
                    actionsOpen = true
                } label: {
                    Image(systemName: "ellipsis")
                        .resizable()
                        .scaledToFit()
                        .frame(width: Theme.iconSize, height: Theme.iconSize)
                        .foregroundStyle(Theme.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.001), in: Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(FullAreaButtonStyle())
                .help("Actions")
                .accessibilityLabel("Actions")
            }
        }
        .frame(width: 36, alignment: .top)
        .fixedSize()
        .allowsHitTesting(true)
        .transition(.scale(scale: 0.72, anchor: .top).combined(with: .opacity))
    }

    private func circleAction(_ symbol: String, help: String, fill: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .resizable()
                .scaledToFit()
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(fill, in: Circle())
                .overlay {
                    Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                }
                .contentShape(Circle())
        }
        .buttonStyle(FullAreaButtonStyle())
        .help(help)
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
