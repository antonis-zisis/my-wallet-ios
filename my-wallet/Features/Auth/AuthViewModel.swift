import Foundation
import Supabase

@Observable
final class AuthViewModel {
    var session: Session?
    var isLoading = true
    var signInError: String?

    var isAuthenticated: Bool { session != nil }
    var token: String? { session?.accessToken }

    /// Called once at app launch. Listens to the Supabase auth state stream for the
    /// lifetime of the app. The first event is always `initialSession` — it carries
    /// the Keychain-persisted session (or nil), which resolves the loading state.
    /// Subsequent events (signedIn, signedOut, tokenRefreshed) keep the session in sync.
    func initialize() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                // Reject expired sessions so the user is sent to LoginView
                self.session = session.flatMap { $0.isExpired ? nil : $0 }
                isLoading = false
            case .signedIn, .tokenRefreshed:
                self.session = session
            case .signedOut, .userDeleted:
                self.session = nil
            default:
                break
            }
        }
    }

    func signIn(email: String, password: String) async {
        signInError = nil
        do {
            session = try await supabase.auth.signIn(email: email, password: password)
        } catch {
            signInError = error.localizedDescription
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        session = nil
    }
}
