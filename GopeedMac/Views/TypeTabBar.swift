import SwiftUI

/// 60pt fully rounded type filter. Selected pill uses the file-type color.
struct TypeTabBar: View {
    @Binding var selection: FileKind.Category
    @Namespace private var typeNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FileKind.Category.allCases, id: \.self) { category in
                let selected = selection == category
                Button {
                    withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                        selection = category
                    }
                } label: {
                    Image(systemName: category.symbol)
                        .resizable()
                        .scaledToFit()
                        .frame(width: Theme.typeTabIconSize, height: Theme.typeTabIconSize)
                        .foregroundStyle(selected
                            ? (category.usesDarkLabel ? Color.black : Color.white)
                            : (category == .all ? Theme.secondary : category.color))
                        .frame(width: Theme.typeTabItemWidth)
                        .frame(maxHeight: .infinity)
                        .background {
                            if selected {
                                Capsule(style: .continuous)
                                    .fill(category.color)
                                    .padding(4)
                                    .matchedGeometryEffect(id: "typeTabPill", in: typeNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(FullAreaButtonStyle())
                .help(category.title)
                .focusable(false)
                .focusEffectDisabled()
            }
        }
        .sizedGlass(height: Theme.toolbarHeight, cornerRadius: Theme.toolbarHeight / 2)
    }
}
