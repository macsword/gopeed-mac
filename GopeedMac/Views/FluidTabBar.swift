import SwiftUI

/// 60pt fully rounded sliding-pill tabs. Labels fill the capsule so the whole tab is clickable.
struct FluidTabBar: View {
    @Binding var selection: SidebarFilter
    var compact: Bool = false
    @Namespace private var tabNamespace

    var body: some View {
        if compact {
            compactBody
        } else {
            expandedBody
        }
    }

    private var expandedBody: some View {
        HStack(spacing: 0) {
            ForEach(SidebarFilter.allCases, id: \.self) { filter in
                let selected = selection == filter
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        selection = filter
                    }
                } label: {
                    Text(filter.title)
                        .font(.system(size: 15, weight: selected ? .semibold : .medium))
                        .foregroundStyle(selected ? Color.black : Theme.secondary)
                        .frame(width: Theme.tabItemWidth)
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

    private var compactBody: some View {
        Menu {
            Picker("", selection: $selection) {
                ForEach(SidebarFilter.allCases) { filter in
                    Label(filter.title, systemImage: filter.symbol)
                        .tag(filter)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 6) {
                if selection != .all {
                    Circle()
                        .fill(selection == .done ? Theme.success : Theme.accent)
                        .frame(width: 7, height: 7)
                }
                Text(selection.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.secondary)
            }
            .padding(.horizontal, 16)
            .frame(height: Theme.toolbarHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(FullAreaButtonStyle())
        .menuIndicator(.hidden)
        .sizedGlass(height: Theme.toolbarHeight, cornerRadius: Theme.toolbarHeight / 2)
        .help("Filter: \(selection.title)")
        .focusable(false)
    }
}
