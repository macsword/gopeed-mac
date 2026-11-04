import SwiftUI

enum Theme {
    static let hairline = Color.white.opacity(0.14)
    static let secondary = Color(red: 0.62, green: 0.68, blue: 0.78)
    static let tertiary = Color(red: 0.48, green: 0.54, blue: 0.64)
    static let accent = Color(red: 0.23, green: 0.51, blue: 0.96)
    static let success = Color(red: 0.22, green: 0.81, blue: 0.51)
    static let danger = Color(red: 0.72, green: 0.22, blue: 0.28)
    static let remaining = Color(red: 0.20, green: 0.78, blue: 0.55)

    static let cardRadius: CGFloat = 22
    static let paneRadius: CGFloat = 28

    static let spaceXS: CGFloat = 12
    static let spaceSM: CGFloat = 16
    static let spaceMD: CGFloat = 24
    static let spaceLG: CGFloat = 32
    static let spaceXL: CGFloat = 40

    static let toolbarHeight: CGFloat = 60
    static let toolbarFill = Color.black.opacity(0.52)
    static let paneTint = Color.black.opacity(0.78)
}

extension View {
    /// Frosted Liquid Glass. `interactive` stays off unless the surface is a pointer target —
    /// live refraction on large panes is what stalls the compositor.
    func liquidGlass(cornerRadius: CGFloat = Theme.cardRadius, tint: Color? = Color.black.opacity(0.32), clear: Bool = false, interactive: Bool = false) -> some View {
        var glass = clear ? Glass.clear : Glass.regular
        if let tint {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return self.glassEffect(glass, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    /// Dark pane chrome. `opacity` is the black fill (0 = clear, 1 = solid).
    func paneGlass(cornerRadius: CGFloat = Theme.paneRadius, opacity: Double = 0.78) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let tint = Color.black.opacity(min(1, max(0, opacity)))
        return self
            .background(tint, in: shape)
            .glassEffect(Glass.regular.tint(tint), in: shape)
    }

    /// Fully rounded chrome of an explicit size. `glassEffect` shrinks to glyphs, so toolbar
    /// capsules fill a shape of `width`×`height` and let window wallpaper glass show through.
    func sizedGlass(width: CGFloat? = nil, height: CGFloat, cornerRadius: CGFloat, tint: Color = Theme.toolbarFill) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return self
            .frame(width: width, height: height)
            .background(.ultraThinMaterial, in: shape)
            .background(tint, in: shape)
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
            }
            .clipShape(shape)
            .contentShape(shape)
    }
}

/// `.plain` only hits the glyph. This fills the label’s frame so the whole pill/circle is clickable.
struct FullAreaButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .contentShape(Rectangle())
    }
}

/// 60pt fully rounded action chrome. The whole capsule is the hit target.
struct CapsuleActionButtonStyle: ButtonStyle {
    enum Kind {
        case regular, prominent, danger, icon
    }

    var kind: Kind = .regular
    var fillWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = {
            switch kind {
            case .regular, .icon: return Theme.toolbarFill
            case .prominent: return Color.white.opacity(0.92)
            case .danger: return Theme.danger.opacity(0.88)
            }
        }()
        let foreground: Color = kind == .prominent ? Color.black : Color.white
        return configuration.label
            .font(.system(size: 15, weight: .semibold))
            .labelStyle(.titleAndIcon)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(foreground)
            .padding(.horizontal, kind == .icon ? 0 : 16)
            .frame(width: kind == .icon ? Theme.toolbarHeight : nil)
            .frame(maxWidth: kind == .icon ? Theme.toolbarHeight : (fillWidth ? .infinity : nil))
            .frame(minHeight: Theme.toolbarHeight, maxHeight: Theme.toolbarHeight)
            .background(fill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(kind == .prominent ? 0 : 0.16), lineWidth: 1)
            }
            .clipShape(Capsule())
            .contentShape(Capsule())
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

/// Splits the offered width evenly so sibling capsules stay the same size.
struct EqualWidthHStack: Layout {
    var spacing: CGFloat = 12

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let heights = subviews.map { $0.sizeThatFits(.unspecified).height }
        let height = max(heights.max() ?? Theme.toolbarHeight, Theme.toolbarHeight)
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        let count = CGFloat(subviews.count)
        let width = max(0, (bounds.width - spacing * (count - 1)) / count)
        var x = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: x, y: bounds.minY),
                proposal: ProposedViewSize(width: width, height: bounds.height)
            )
            x += width + spacing
        }
    }
}
