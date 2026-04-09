import SwiftUI

struct ReportsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Reports",
                systemImage: "chart.bar.fill",
                description: Text("Your financial reports will appear here.")
            )
            .navigationTitle("Reports")
        }
    }
}

#Preview {
    ReportsView()
}
