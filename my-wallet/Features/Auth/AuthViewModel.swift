import Foundation
import Supabase

@MainActor
@Observable
final class AuthViewModel {
    var session: Session?
    var isLoading = true
    var signInError: String?
    var isBiometricLocked = false
    var biometricLockEnabled: Bool = UserDefaults.standard.object(forKey: "biometricLockEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(biometricLockEnabled, forKey: "biometricLockEnabled") }
    }

    private let biometrics = BiometricAuthService()

    var isAuthenticated: Bool { session != nil }
    var token: String? { session?.accessToken }
    var canUseBiometrics: Bool { biometrics.canUseBiometrics }

    /// Called once at app launch. Listens to the Supabase auth state stream for the
    /// lifetime of the app. The first event is always `initialSession` — it carries
    /// the Keychain-persisted session (or nil), which resolves the loading state.
    /// Subsequent events (signedIn, signedOut, tokenRefreshed) keep the session in sync.
    func initialize() async {
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession:
                // Reject expired sessions so the user is sent to LoginView
                let validSession = session.flatMap { $0.isExpired ? nil : $0 }
                self.session = validSession
                // If a valid session was restored from Keychain, lock behind biometrics
                if validSession != nil {
                    isBiometricLocked = biometrics.canUseBiometrics && biometricLockEnabled
                }
                isLoading = false
            case .signedIn, .tokenRefreshed:
                self.session = session
            case .signedOut, .userDeleted:
                self.session = nil
                isBiometricLocked = false
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

    func unlockWithBiometrics() async {
        let success = await biometrics.authenticate()
        if success {
            isBiometricLocked = false
        }
    }

    func lockOnBackground() {
        guard isAuthenticated, biometrics.canUseBiometrics, biometricLockEnabled else { return }
        isBiometricLocked = true
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        session = nil
        isBiometricLocked = false
    }
}
