import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Dashboard",
                systemImage: "house.fill",
                description: Text("Your financial overview will appear here.")
            )
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
