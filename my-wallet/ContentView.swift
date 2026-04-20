import SwiftUI

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
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

            NetWorthView()
                .tabItem {
                    Label("Net Worth", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(3)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
}
