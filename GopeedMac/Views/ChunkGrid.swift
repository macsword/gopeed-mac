import SwiftUI

struct ChunkGrid: View {
    var completed: Int
    var total: Int

    private let columns = 32

    var body: some View {
        let count = max(total, 1)
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
                let pitchX = size.width / CGFloat(columns)
                let pitchY = size.height / CGFloat(rows)
                let cell = min(pitchX, pitchY) * 0.36
                let doneFill = Theme.accent
                let idleFill = Color.white.opacity(0.12)
                for index in 0..<shown {
                    let column = index % columns
                    let row = index / columns
                    let rect = CGRect(
                        x: CGFloat(column) * pitchX + (pitchX - cell) / 2,
                        y: CGFloat(row) * pitchY + (pitchY - cell) / 2,
                        width: cell,
                        height: cell
                    )
                    context.fill(Path(ellipseIn: rect), with: .color(index < completed ? doneFill : idleFill))
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(CGFloat(columns) / CGFloat(rows), contentMode: .fit)
            .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
