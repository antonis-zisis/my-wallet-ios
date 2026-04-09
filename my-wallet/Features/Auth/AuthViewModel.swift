import Foundation
import Supabase

@Observable
final class AuthViewModel {
    var session: Session?
    var isLoading = true
    var signInError: String?

    var isAuthenticated: Bool { session != nil }
    var token: String? { session?.accessToken }

    /// Called once at app launch. Restores a Keychain-persisted session if available.
    func initialize() async {
        session = try? await supabase.auth.session
        isLoading = false
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
