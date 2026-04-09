import SwiftUI

struct ProfileView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Profile",
                systemImage: "person.fill",
                description: Text("Your profile and settings will appear here.")
            )
            .navigationTitle("Profile")
        }
    }
}

#Preview {
    ProfileView()
}
