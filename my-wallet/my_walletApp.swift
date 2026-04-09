import SwiftUI

@main
struct my_walletApp: App {
    @State private var auth = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .task {
                    await auth.initialize()
                }
        }
    }
}

/// Switches between LoginView and the main TabView based on auth state.
struct RootView: View {
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        if auth.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if auth.isAuthenticated {
            ContentView()
        } else {
            LoginView()
        }
    }
}
