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

            MoreView()
                .tabItem {
                    Label("More", systemImage: "ellipsis")
                }
                .tag(4)
        }
    }
}

private struct MoreView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    NetWorthView()
                } label: {
                    Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
                }

                NavigationLink {
                    ProfileView()
                } label: {
                    Label("Profile", systemImage: "person.fill")
                }
            }
            .navigationTitle("More")
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
        .environment(AppRouter())
}
