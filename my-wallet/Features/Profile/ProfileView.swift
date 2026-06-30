import SwiftUI

struct ProfileView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AuthViewModel.self) private var auth

    @State private var vm = ProfileViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                userHeader
                personalInfoCard
                changePasswordCard
                if auth.canUseBiometrics {
                    biometricCard
                }
                preferencesCard
                aboutCard
                signOutCard
            }
            .padding()
        }
        .background(AppColors.bgApp)
        .navigationTitle("Profile")
        .task {
            guard let token = auth.token else { return }
            await vm.loadUser(token: token)
        }
        .overlay {
            if vm.isLoading { ProgressView() }
        }
        .alert("Error", isPresented: Binding(
            get: { vm.errorMessage != nil },
            set: { if !$0 { vm.errorMessage = nil } }
        )) {
            Button("OK") { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
        .alert("Success", isPresented: Binding(
            get: { vm.successMessage != nil },
            set: { if !$0 { vm.successMessage = nil } }
        )) {
            Button("OK") { vm.successMessage = nil }
        } message: {
            Text(vm.successMessage ?? "")
        }
    }

    // MARK: - Header

    private var userHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppColors.brand)
                Text(initials(from: vm.fullName.isEmpty ? vm.email : vm.fullName))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 2) {
                Text(vm.fullName.isEmpty ? vm.email : vm.fullName)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if !vm.fullName.isEmpty {
                    Text(vm.email)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Cards

    private var personalInfoCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Text("Personal info")
                    .font(.headline)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Email")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(vm.email.isEmpty ? "—" : vm.email)
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Full name")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Enter your full name", text: $vm.editingFullName)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.words)
                }

                Divider().padding(.vertical, 12)

                Button {
                    Task {
                        guard let token = auth.token else { return }
                        await vm.saveFullName(token: token)
                    }
                } label: {
                    Group {
                        if vm.isSavingName {
                            ProgressView()
                        } else {
                            Text("Save")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.body.weight(.medium))
                }
                .disabled(vm.isNameUnchanged || vm.isSavingName)
            }
        }
    }

    private var changePasswordCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Text("Change Password")
                    .font(.headline)
                    .padding(.bottom, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("New password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Enter new password", text: $vm.newPassword)
                }

                Divider().padding(.vertical, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Confirm password")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    SecureField("Confirm new password", text: $vm.confirmPassword)
                }

                Divider().padding(.vertical, 12)

                Button {
                    Task { await vm.savePassword() }
                } label: {
                    Group {
                        if vm.isSavingPassword {
                            ProgressView()
                        } else {
                            Text("Change password")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .font(.body.weight(.medium))
                }
                .disabled(vm.newPassword.isEmpty || vm.confirmPassword.isEmpty || vm.isSavingPassword)
            }
        }
    }

    private var biometricCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Text("Face ID")
                    .font(.headline)
                    .padding(.bottom, 16)

                @Bindable var auth = auth
                Toggle(isOn: $auth.biometricLockEnabled) {
                    Label("Require Face ID", systemImage: "faceid")
                }
            }
        }
    }

    private var preferencesCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Text("Preferences")
                    .font(.headline)
                    .padding(.bottom, 16)

                @Bindable var theme = theme
                Toggle(isOn: $theme.hideAmounts) {
                    Label("Hide amounts", systemImage: "eye.slash")
                }

                Divider().padding(.vertical, 12)

                Text("Appearance")
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 10)

                HStack {
                    ForEach(AppTheme.allCases) { appTheme in
                        ThemeOption(
                            appTheme: appTheme,
                            isSelected: theme.current == appTheme
                        ) {
                            theme.current = appTheme
                        }
                    }
                }
            }
        }
    }

    private var aboutCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Text("About")
                    .font(.headline)
                    .padding(.bottom, 16)

                HStack {
                    Text("Version")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text("v\(appVersion)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider().padding(.vertical, 12)

                Text("Subscription logos provided by ")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                + Text("[Logo.dev](https://logo.dev)")
                    .font(.caption)
            }
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var signOutCard: some View {
        CardContainer {
            Button(role: .destructive) {
                Task { await auth.signOut() }
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                    Text("Sign Out")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .font(.body.weight(.medium))
            }
        }
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        if parts.isEmpty { return "?" }
        return parts.compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }
}

// MARK: - Theme Option Button

private struct ThemeOption: View {
    let appTheme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 6) {
                Image(systemName: appTheme.icon)
                    .font(.title3)
                Text(appTheme.rawValue)
                    .font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor.opacity(0.12) : AppColors.surfaceMuted)
            .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environment(ThemeManager())
        .environment(AuthViewModel())
}
