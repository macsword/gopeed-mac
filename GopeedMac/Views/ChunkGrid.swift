import SwiftUI

struct ChunkGrid: View {
    var completed: Int
    var total: Int

    var body: some View {
        let count = max(total, 1)
        let columns = 32
        let rows = max(8, Int(ceil(Double(count) / Double(columns))))
        let shown = min(count, columns * rows)

        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack {
                Text("Pieces / Chunks (\(count))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
                Spacer()
                Text("\(min(completed, count)) / \(count) completed")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.tertiary)
            }

            Canvas { context, size in
                let spacing: CGFloat = 6
                let cell = min(6, (size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns))
                let doneFill = Theme.accent
                let idleFill = Color.white.opacity(0.12)
                for index in 0..<shown {
                    let column = index % columns
                    let row = index / columns
                    let rect = CGRect(
                        x: CGFloat(column) * (cell + spacing),
                        y: CGFloat(row) * (cell + spacing),
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(index < completed ? doneFill : idleFill))
                }
            }
            .frame(height: CGFloat(rows) * 12)
            .accessibilityHidden(true)
        }
    }
}
