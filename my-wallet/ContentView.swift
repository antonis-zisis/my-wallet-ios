import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        TabView(selection: $router.selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Overview", systemImage: "house.fill")
                }
                .tag(0)

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text")
                }
                .tag(1)

            SubscriptionsView()
                .tabItem {
                    Label("Subscriptions", systemImage: "repeat.circle")
                }
                .tag(2)

            ContractsView()
                .tabItem {
                    Label("Contracts", systemImage: "doc.plaintext")
                }
                .tag(3)

            NetWorthView()
                .tabItem {
                    Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(4)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(5)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
        .environment(AppRouter())
}
