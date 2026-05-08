import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    private var isFormValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        VStack(spacing: 28) {
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
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(focusedField == .email ? AppColors.borderStrong : AppColors.border, lineWidth: 1)
                    )
                    .focused($focusedField, equals: .email)

                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .padding()
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(focusedField == .password ? AppColors.borderStrong : AppColors.border, lineWidth: 1)
                    )
                    .focused($focusedField, equals: .password)

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
                    .padding()
                    .background(isFormValid && !isSubmitting ? Color.accentColor : Color.accentColor.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(!isFormValid || isSubmitting)

                if let error = auth.signInError {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text(error)
                    }
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
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
