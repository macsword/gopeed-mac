import SwiftUI

/// Shows each HTTP connection reported by the engine as its own lane.
///
/// Lanes are connections, not fixed byte ranges: the engine reports each
/// connection's bytes against an equal nominal share of the file, and may add
/// or rebalance connections while downloading. The view says so instead of
/// drawing a file map it cannot know.
struct ChunkGrid: View {
    /// `nil` = engine has not reported stats for this task (yet).
    var stats: TaskStats?
    var taskIsDone: Bool

    private var connections: [StatConnection]? { stats?.connections }

    private let columns = [GridItem(.adaptive(minimum: 120), spacing: Theme.spaceXS)]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: Theme.spaceXS)
                if let summary {
                    Text(summary)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.tertiary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            if let connections, !connections.isEmpty {
                LazyVGrid(columns: columns, alignment: .leading, spacing: Theme.spaceXS) {
                    ForEach(Array(connections.enumerated()), id: \.offset) { index, connection in
                        ConnectionLane(index: index + 1, connection: connection)
                    }
                }
                Text("Each bar is one connection's bytes against an equal share of the file. Connections can be added or rebalanced, so these are estimates, not byte ranges.")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spaceSM)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        guard let connections, !connections.isEmpty else { return "Connections" }
        return "Connections (\(connections.count))"
    }

    private var summary: String? {
        guard let connections, !connections.isEmpty else { return nil }
        let done = connections.filter { $0.state == .completed }.count
        let failed = connections.filter { $0.state == .failed }.count
        var text = "\(done) / \(connections.count) finished"
        if failed > 0 { text += " • \(failed) failed" }
        return text
    }

    private var emptyMessage: String {
        if stats == nil {
            return taskIsDone
                ? "No per-connection data was recorded for this download."
                : "Waiting for per-connection data from the engine…"
        }
        return "This download has no HTTP connections to show (for example torrents, or a server that doesn't support split downloads)."
    }
}

private struct ConnectionLane: View {
    var index: Int
    var connection: StatConnection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("#\(index)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer(minLength: 2)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(stateColor)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    if let fraction = connection.fraction {
                        Capsule()
                            .fill(stateColor)
                            .frame(width: max(0, geo.size.width * fraction))
                    } else if connection.state == .failed {
                        Capsule().fill(stateColor.opacity(0.6))
                    }
                }
            }
            .frame(height: 6)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Connection \(index), \(accessibilityState)")
        .help(helpText)
    }

    private var stateColor: Color {
        switch connection.state {
        case .completed: return Theme.success
        case .failed: return .orange
        case .active: return Theme.accent
        }
    }

    private var detail: String {
        switch connection.state {
        case .completed: return "Done"
        case .failed: return "Failed"
        case .active:
            if let fraction = connection.fraction {
                return "\(Int((fraction * 100).rounded(.down)))%"
            }
            return ByteFormat.string(connection.downloaded ?? 0)
        }
    }

    private var accessibilityState: String {
        switch connection.state {
        case .completed: return "finished"
        case .failed: return "failed"
        case .active: return detail
        }
    }

    private var helpText: String {
        var parts = ["Downloaded \(ByteFormat.string(connection.downloaded ?? 0))"]
        if let total = connection.total, total > 0 {
            parts.append("of an estimated \(ByteFormat.string(total)) share")
        }
        if let retries = connection.retryTimes, retries > 0 {
            parts.append("• \(retries) retr\(retries == 1 ? "y" : "ies")")
        }
        return parts.joined(separator: " ")
    }
}
