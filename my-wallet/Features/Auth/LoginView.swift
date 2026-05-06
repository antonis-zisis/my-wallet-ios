import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            // Logo & title
            VStack(spacing: 12) {
                Image("LaunchIcon")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.tint)

                Text("My Wallet")
                    .font(.largeTitle.bold())

                Text("Sign in to your account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Form
            VStack(spacing: 14) {
                TextField("Email", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if let error = auth.signInError {
                    Label(error, systemImage: "exclamationmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button {
                    isSubmitting = true
                    Task {
                        await auth.signIn(email: email, password: password)
                        isSubmitting = false
                    }
                } label: {
                    Group {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Sign In").fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!isFormValid || isSubmitting)
            }

            Spacer()
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 440)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.bgApp)
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
