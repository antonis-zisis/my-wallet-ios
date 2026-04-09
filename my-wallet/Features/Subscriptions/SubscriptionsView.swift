import SwiftUI

struct SubscriptionsView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Subscriptions",
                systemImage: "arrow.clockwise",
                description: Text("Your recurring payments will appear here.")
            )
            .navigationTitle("Subscriptions")
        }
    }
}

#Preview {
    SubscriptionsView()
}
