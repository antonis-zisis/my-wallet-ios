import SwiftUI

struct ProfileView: View {
    @Environment(ThemeManager.self) private var theme
    @Environment(AuthViewModel.self) private var auth

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    @Bindable var theme = theme

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
                    .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                Section {
                    Button(role: .destructive) {
                        Task { await auth.signOut() }
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sign Out")
                        }
                    }
                }
            }
            .navigationTitle("Profile")
            .listStyle(.insetGrouped)
        }
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
            .background(isSelected ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemBackground))
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
