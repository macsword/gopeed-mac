import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DownloadStore
    @Namespace private var glassSpace
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            WindowWallpaperGlass()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                toolbar
                GlassEffectContainer(spacing: 0) {
                    HStack(alignment: .top, spacing: Theme.spaceMD) {
                        DownloadListPane()
                            .frame(minWidth: 280)
                            .frame(maxWidth: store.inspectorCollapsed ? .infinity : 520)
                            .frame(maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.paneRadius, style: .continuous))
                            .paneGlass(opacity: store.panelOpacity)
                            .glassEffectUnion(id: "list", namespace: glassSpace)

                        if store.inspectorCollapsed {
                            Button {
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    store.inspectorCollapsed = false
                                }
                            } label: {
                                Image(systemName: "sidebar.right")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                                    .foregroundStyle(Theme.secondary)
                                    .frame(width: 44, height: 120)
                                    .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            }
                            .buttonStyle(FullAreaButtonStyle())
                            .liquidGlass(cornerRadius: 18)
                            .glassEffectUnion(id: "inspectorToggle", namespace: glassSpace)
                            .help("Show Inspector")
                        } else {
                            InspectorPane()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.paneRadius, style: .continuous))
                                .paneGlass(opacity: store.panelOpacity)
                                .glassEffectUnion(id: "inspector", namespace: glassSpace)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, Theme.spaceMD)
                    .padding(.bottom, Theme.spaceMD)
                }
            }
        }
        .preferredColorScheme(.dark)
        .background(.clear)
        .containerBackground(.clear, for: .window)
        .sheet(isPresented: $store.showingAdd) {
            AddDownloadSheet()
                .environmentObject(store)
        }
        .sheet(isPresented: $store.showingSettings) {
            SettingsView()
                .environmentObject(store)
        }
        .alert("Engine", isPresented: Binding(
            get: { store.engineError != nil },
            set: { if !$0 { store.engineError = nil } }
        )) {
            Button("OK", role: .cancel) { store.engineError = nil }
        } message: {
            Text(store.engineError ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .gopeedNewDownload)) { _ in
            store.showingAdd = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .gdmDropTargeted)) { note in
            dropTargeted = note.object as? Bool ?? false
        }
        .onReceive(NotificationCenter.default.publisher(for: .gdmDroppedLinks)) { note in
            guard let links = note.object as? [String] else { return }
            Task { await store.addLinks(links) }
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: Theme.paneRadius, style: .continuous)
                    .fill(Color.black.opacity(0.28))
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 28, weight: .semibold))
                            Text("Drop links to download")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                    }
                    .padding(Theme.spaceLG)
                    .allowsHitTesting(false)
            }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: 68, height: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FluidTabBar(selection: $store.filter)
                    TypeTabBar(selection: $store.typeFilter)
                }
            }

            SearchBar(text: $store.search)
                .id("gdm.search")

            Menu {
                Picker("Sort By", selection: $store.sort) {
                    ForEach(TaskSort.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                Button(store.sortAscending ? "Sort Descending" : "Sort Ascending") {
                    store.sortAscending.toggle()
                }
            } label: {
                Image(systemName: "line.3.horizontal.decrease")
                    .resizable()
                    .scaledToFit()
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                    .foregroundStyle(Theme.secondary)
                    .frame(width: Theme.toolbarHeight, height: Theme.toolbarHeight)
                    .contentShape(Circle())
            }
            .buttonStyle(FullAreaButtonStyle())
            .menuIndicator(.hidden)
            .sizedGlass(width: Theme.toolbarHeight, height: Theme.toolbarHeight, cornerRadius: Theme.toolbarHeight / 2)
            .help("Sort downloads")
            .focusable(false)
        }
        .frame(height: Theme.toolbarHeight)
        .padding(.top, 8)
        .padding(.trailing, 16)
        .padding(.bottom, 14)
    }
}

private struct SearchBar: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: Theme.iconSize, height: Theme.iconSize)
                .foregroundStyle(Theme.tertiary)
            TextField("Search downloads...", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .background(.clear)
                .focused($focused)
        }
        .padding(.horizontal, 22)
        .frame(minWidth: 160, idealWidth: 200, maxWidth: 240)
        .layoutPriority(1)
        .sizedGlass(height: Theme.toolbarHeight, cornerRadius: Theme.toolbarHeight / 2)
    }
}
