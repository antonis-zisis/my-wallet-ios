import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "house.fill")
                }

            ReportsView()
                .tabItem {
                    Label("Reports", systemImage: "doc.text")
                }

            SubscriptionsView()
                .tabItem {
                    Label("Subscriptions", systemImage: "repeat.circle")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
}
