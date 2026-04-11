import SwiftUI

struct BiometricLockView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var isAuthenticating = false

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "faceid")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("My Wallet")
                    .font(.largeTitle.bold())

                Text("Unlock to continue")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                isAuthenticating = true
                Task {
                    await auth.unlockWithBiometrics()
                    isAuthenticating = false
                }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isAuthenticating)
            .padding(.horizontal, 32)

            Button("Sign in with password") {
                Task { await auth.signOut() }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: 440)
        .task {
            // Automatically prompt Face ID on appearance
            await auth.unlockWithBiometrics()
        }
    }
}
