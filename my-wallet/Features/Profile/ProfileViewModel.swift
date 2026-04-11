import Foundation
import Supabase

// MARK: - GraphQL

private let meQuery = """
  query Me {
    me {
      id
      email
      fullName
    }
  }
"""

private let updateMeMutation = """
  mutation UpdateMe($input: UpdateUserInput!) {
    updateMe(input: $input) {
      id
      email
      fullName
    }
  }
"""

// MARK: - Response types

private struct UserPayload: Decodable {
    let id: String
    let email: String
    let fullName: String?
}

private struct MeResponse: Decodable {
    let me: UserPayload
}

private struct UpdateMeResponse: Decodable {
    let updateMe: UserPayload
}

// MARK: - ViewModel

@MainActor
@Observable
final class ProfileViewModel {
    var email: String = ""
    var fullName: String = ""
    var editingFullName: String = ""

    var newPassword: String = ""
    var confirmPassword: String = ""

    var isLoading = false
    var isSavingName = false
    var isSavingPassword = false

    var errorMessage: String?
    var successMessage: String?

    var isNameUnchanged: Bool { editingFullName.trimmingCharacters(in: .whitespaces) == fullName }

    private let client = GraphQLClient.shared

    func loadUser(token: String) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let response: MeResponse = try await client.perform(query: meQuery, token: token)
            applyUser(response.me)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveFullName(token: String) async {
        let trimmed = editingFullName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSavingName = true
        clearMessages()
        defer { isSavingName = false }

        do {
            struct Vars: Encodable {
                struct Input: Encodable { let fullName: String }
                let input: Input
            }
            let response: UpdateMeResponse = try await client.perform(
                query: updateMeMutation,
                variables: Vars(input: .init(fullName: trimmed)),
                token: token
            )
            applyUser(response.updateMe)
            successMessage = "Profile updated."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func savePassword() async {
        let trimmedNew = newPassword.trimmingCharacters(in: .whitespaces)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespaces)

        if trimmedNew != trimmedConfirm {
            errorMessage = "Passwords do not match."
            return
        }
        if trimmedNew.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }

        isSavingPassword = true
        clearMessages()
        defer { isSavingPassword = false }

        do {
            try await supabase.auth.update(user: UserAttributes(password: trimmedNew))
            newPassword = ""
            confirmPassword = ""
            successMessage = "Password changed."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Private

    private func applyUser(_ user: UserPayload) {
        email = user.email
        fullName = user.fullName ?? ""
        editingFullName = user.fullName ?? ""
    }

    private func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
}
