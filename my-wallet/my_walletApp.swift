import SwiftUI

@main
struct my_walletApp: App {
    @State private var auth = AuthViewModel()
    @State private var theme = ThemeManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(auth)
                .environment(theme)
                .preferredColorScheme(theme.colorScheme)
                .task {
                    await auth.initialize()
                }
        }
    }
}

/// Switches between LoginView and the main TabView based on auth state.
struct RootView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ThemeManager.self) private var theme

    var body: some View {
        if auth.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if auth.isAuthenticated {
            ContentView()
                .environment(auth)
                .environment(theme)
        } else {
            LoginView()
                .environment(auth)
        }
    }
}
