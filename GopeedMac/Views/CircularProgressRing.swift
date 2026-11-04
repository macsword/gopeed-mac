import SwiftUI

struct CircularProgressRing: View {
    var progress: Double
    var color: Color
    var hovering: Bool
    var hoverSymbol: String?
    var lineWidth: CGFloat = 7.5

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(1, max(0, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if hovering, let hoverSymbol {
                Image(systemName: hoverSymbol)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.white)
                    .transition(.opacity.combined(with: .scale(scale: 0.86)))
            } else {
                Text("\(Int((progress * 100).rounded()))%")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .transition(.opacity)
            }
        }
        .frame(width: 78, height: 78)
        .contentShape(Circle())
        .animation(.easeInOut(duration: 0.12), value: hovering)
    }
}
