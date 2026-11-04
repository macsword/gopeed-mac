import SwiftUI

struct SpeedChart: View {
    var samples: [SpeedSample]
    var current: Int64

    var body: some View {
        let points = normalized
        VStack(alignment: .leading, spacing: Theme.spaceSM) {
            HStack {
                Text("Download Speed (Last 60 Seconds)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Current: \(ByteFormat.speed(current))")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent)
            }

            GeometryReader { geo in
                let maxY: CGFloat = 20
                ZStack(alignment: .leading) {
                    VStack {
                        ForEach([20, 15, 10, 5, 0], id: \.self) { tick in
                            HStack(spacing: Theme.spaceXS) {
                                Text("\(tick) MB/s")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.tertiary)
                                    .frame(width: 46, alignment: .trailing)
                                Rectangle()
                                    .fill(Color.white.opacity(0.06))
                                    .frame(height: 1)
                            }
                            if tick != 0 { Spacer() }
                        }
                    }

                    Path { path in
                        guard points.count > 1 else { return }
                        let chartWidth = geo.size.width - 54
                        let chartHeight = geo.size.height
                        for (index, value) in points.enumerated() {
                            let x = 54 + CGFloat(index) / CGFloat(points.count - 1) * chartWidth
                            let y = chartHeight - CGFloat(value / 20) * chartHeight
                            if index == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 92)
            .drawingGroup()

            HStack {
                Text("-60s").frame(width: 46)
                Text("-45s")
                Spacer()
                Text("-30s")
                Spacer()
                Text("-15s")
                Spacer()
                Text("Now")
            }
            .font(.system(size: 10))
            .foregroundStyle(Theme.tertiary)
            .padding(.leading, Theme.spaceSM)
        }
        .padding(Theme.spaceLG)
        .liquidGlass(cornerRadius: 20)
    }

    private var normalized: [Double] {
        let values = samples.map { min(20, Double($0.bytesPerSecond) / 1_000_000) }
        if values.isEmpty { return [0, 0] }
        if values.count == 1 { return [values[0], values[0]] }
        return values
    }
}
