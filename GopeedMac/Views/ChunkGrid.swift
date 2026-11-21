import SwiftUI

/// FDM-style byte-range dot map for HTTP connection progress.
///
/// The whole grid represents the full file. Each connection owns an equal
/// contiguous segment of the file (connection 0 → bytes [0, share),
/// connection 1 → bytes [share, 2*share), etc.). Dots inside each segment
/// are filled left-to-right as `downloaded` grows.
struct ChunkGrid: View {
    var stats: TaskStats?
    var taskIsDone: Bool

    private var connections: [StatConnection]? { stats?.connections }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            // Header row
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
                PieceMap(connections: connections)
            } else {
                Text(emptyMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Theme.spaceSM)
                    .background(Color.white.opacity(0.05),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        guard let c = connections, !c.isEmpty else { return "Connections" }
        return "Connections (\(c.count))"
    }

    private var summary: String? {
        guard let c = connections, !c.isEmpty else { return nil }
        let done   = c.filter { $0.state == .completed }.count
        let failed = c.filter { $0.state == .failed }.count
        var text   = "\(done) / \(c.count) finished"
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

// MARK: - Piece map

private struct PieceMap: View {
    var connections: [StatConnection]

    // Dot appearance
    private let dotSize:   CGFloat = 5
    private let dotGap:    CGFloat = 2
    private let mapHeight: CGFloat = 64
    private let cornerRatio: CGFloat = 0.3

    var body: some View {
        Canvas { ctx, size in
            let step = dotSize + dotGap
            let cols = max(1, Int((size.width  + dotGap) / step))
            let rows = max(1, Int((size.height + dotGap) / step))
            let totalDots = cols * rows

            let count = connections.count
            guard count > 0 else { return }

            // Each connection's share of the total file (in dots).
            // `connection.total` is fileSize/count, so all shares are equal.
            // We use the dot count directly for integer precision.
            let slabSize = Double(totalDots) / Double(count)

            for connIdx in connections.indices {
                let conn = connections[connIdx]

                let slabStart = Int((Double(connIdx)     * slabSize).rounded())
                let slabEnd   = Int((Double(connIdx + 1) * slabSize).rounded())
                let slabCount = slabEnd - slabStart
                guard slabCount > 0 else { continue }

                // How many dots in this slab are filled (downloaded)?
                let filledCount: Int = {
                    switch conn.state {
                    case .completed:
                        return slabCount
                    case .failed:
                        // Show the bytes downloaded before the failure.
                        guard let f = conn.fraction else { return 0 }
                        return max(0, Int((f * Double(slabCount)).rounded()))
                    case .active:
                        guard let f = conn.fraction else { return 0 }
                        return max(0, Int((f * Double(slabCount)).rounded()))
                    }
                }()

                let filledColor   = fillColor(for: conn)
                let emptyColor    = Color.white.opacity(0.09)
                let cornerRadius  = dotSize * cornerRatio

                for localIdx in 0 ..< slabCount {
                    let globalIdx = slabStart + localIdx
                    let col = globalIdx % cols
                    let row = globalIdx / cols

                    let x = CGFloat(col) * step
                    let y = CGFloat(row) * step
                    let rect = CGRect(x: x, y: y, width: dotSize, height: dotSize)
                    let path = Path(roundedRect: rect,
                                    cornerRadius: cornerRadius)

                    let color = localIdx < filledCount ? filledColor : emptyColor
                    ctx.fill(path, with: .color(color))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: mapHeight)
    }

    private func fillColor(for conn: StatConnection) -> Color {
        switch conn.state {
        case .completed: return Theme.success
        case .failed:    return .orange
        case .active:    return Theme.accent
        }
    }
}
