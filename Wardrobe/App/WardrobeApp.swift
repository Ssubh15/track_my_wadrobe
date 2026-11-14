import SwiftUI

@main
struct WardrobeApp: App {
    private let dependencies = DIContainer()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .environment(dependencies)
        }
    }
}

private struct AppTabView: View {
    @Environment(DIContainer.self) private var dependencies
    @State private var selectedTab: AppTab = .wardrobe
    @State private var isAddPresented = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            tabs
            if !hasSeenOnboarding {
                OnboardingView { withAnimation { hasSeenOnboarding = true } }
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { WardrobeHomeView(repository: dependencies.wardrobeRepository, imageStore: dependencies.imageStore) }
                .tabItem { Label("Wardrobe", systemImage: "tshirt") }
                .tag(AppTab.wardrobe)

            Color.clear
                .tabItem { Label("Add", systemImage: "plus.circle.fill") }
                .tag(AppTab.add)

            InsightsView(repository: dependencies.wardrobeRepository)
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(AppTab.insights)

            SettingsView(repository: dependencies.wardrobeRepository)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .tint(Theme.Colors.accent)
        .onChange(of: selectedTab) { _, tab in
            guard tab == .add else { return }
            isAddPresented = true
            selectedTab = .wardrobe
        }
        .fullScreenCover(isPresented: $isAddPresented) {
            AddItemEntryView(onClose: { isAddPresented = false })
                .environment(dependencies)
        }
    }
}

private enum AppTab: Hashable {
    case wardrobe, add, insights, settings
}

#Preview {
    AppTabView()
        .environment(DIContainer())
}
