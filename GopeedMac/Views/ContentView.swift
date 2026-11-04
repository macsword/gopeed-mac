import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DownloadStore
    @Namespace private var glassSpace

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
                            .paneGlass(opacity: store.panelOpacity)
                            .glassEffectUnion(id: "list", namespace: glassSpace)

                        if store.inspectorCollapsed {
                            Button {
                                withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                    store.inspectorCollapsed = false
                                }
                            } label: {
                                Image(systemName: "sidebar.right")
                                    .font(.system(size: 14, weight: .semibold))
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
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 68, height: 12)

            FluidTabBar(selection: $store.filter)

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.tertiary)
                TextField("Search downloads...", text: $store.search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .foregroundStyle(.white)
                    .background(.clear)
            }
            .padding(.horizontal, 22)
            .frame(minWidth: 140, maxWidth: 280)
            .sizedGlass(height: Theme.toolbarHeight, cornerRadius: Theme.toolbarHeight / 2)

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
                    .font(.system(size: 16, weight: .semibold))
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
