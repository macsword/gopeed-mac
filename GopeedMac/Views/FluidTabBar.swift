import SwiftUI

/// 60pt fully rounded sliding-pill tabs. Labels fill the capsule so the whole tab is clickable.
struct FluidTabBar: View {
    @Binding var selection: SidebarFilter
    @Namespace private var tabNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(SidebarFilter.allCases) { filter in
                let selected = selection == filter
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        selection = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(.system(size: 15, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.black : Theme.secondary)
                        .padding(.horizontal, 24)
                        .frame(maxHeight: .infinity)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(Color.white)
                                    .padding(4)
                                    .matchedGeometryEffect(id: "fluidTabPill", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(FullAreaButtonStyle())
                .focusable(false)
                .focusEffectDisabled()
            }
        }
        .sizedGlass(height: Theme.toolbarHeight, cornerRadius: Theme.toolbarHeight / 2)
    }
}
