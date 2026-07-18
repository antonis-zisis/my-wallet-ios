import Foundation

// MARK: - GraphQL

private let getReportQuery = """
  query GetReport($id: ID!) {
    report(id: $id) {
      id
      title
      isLocked
      createdAt
      updatedAt
      transactions {
        id
        reportId
        type
        amount
        description
        category
        date
        createdAt
        updatedAt
      }
    }
  }
"""

private let getReportSharingQuery = """
  query GetReportSharing($id: ID!) {
    report(id: $id) {
      id
      myRole
      members {
        email
        fullName
        id
        role
        userId
      }
    }
  }
"""

private let updateReportMutation = """
  mutation UpdateReport($input: UpdateReportInput!) {
    updateReport(input: $input) {
      id
      title
      updatedAt
    }
  }
"""

private let lockReportMutation = """
  mutation LockReport($id: ID!) {
    lockReport(id: $id) {
      id
      isLocked
    }
  }
"""

private let unlockReportMutation = """
  mutation UnlockReport($id: ID!) {
    unlockReport(id: $id) {
      id
      isLocked
    }
  }
"""

private let deleteReportMutation = """
  mutation DeleteReport($id: ID!) {
    deleteReport(id: $id)
  }
"""

private let createTransactionMutation = """
  mutation CreateTransaction($input: CreateTransactionInput!) {
    createTransaction(input: $input) {
      id
      reportId
      type
      amount
      description
      category
      date
      createdAt
      updatedAt
    }
  }
"""

private let updateTransactionMutation = """
  mutation UpdateTransaction($input: UpdateTransactionInput!) {
    updateTransaction(input: $input) {
      id
      reportId
      type
      amount
      description
      category
      date
      createdAt
      updatedAt
    }
  }
"""

private let deleteTransactionMutation = """
  mutation DeleteTransaction($id: ID!) {
    deleteTransaction(id: $id)
  }
"""

private let shareReportMutation = """
  mutation ShareReport($input: ShareReportInput!) {
    shareReport(input: $input) {
      id
      members {
        email
        fullName
        id
        role
        userId
      }
    }
  }
"""

private let updateReportShareRoleMutation = """
  mutation UpdateReportShareRole($input: UpdateReportShareRoleInput!) {
    updateReportShareRole(input: $input) {
      id
      members {
        email
        fullName
        id
        role
        userId
      }
    }
  }
"""

private let unshareReportMutation = """
  mutation UnshareReport($id: ID!) {
    unshareReport(id: $id) {
      id
      members {
        email
        fullName
        id
        role
        userId
      }
    }
  }
"""

private let leaveSharedReportMutation = """
  mutation LeaveSharedReport($reportId: ID!) {
    leaveSharedReport(reportId: $reportId)
  }
"""

// MARK: - Response types

private struct ReportResponse: Decodable { let report: Report? }
private struct UpdateReportResult: Decodable { let id: String; let title: String; let updatedAt: String }
private struct UpdateReportResponse: Decodable { let updateReport: UpdateReportResult }
private struct LockResult: Decodable { let id: String; let isLocked: Bool }
private struct LockReportResponse: Decodable { let lockReport: LockResult }
private struct UnlockReportResponse: Decodable { let unlockReport: LockResult }
private struct CreateTransactionResponse: Decodable { let createTransaction: Transaction }
private struct UpdateTransactionResponse: Decodable { let updateTransaction: Transaction }
private struct DeleteTransactionResponse: Decodable { let deleteTransaction: Bool }

private struct SharingInfo: Decodable { let id: String; let myRole: ReportRole?; let members: [ReportMember]? }
private struct ReportSharingResponse: Decodable { let report: SharingInfo? }
private struct ReportMembersResult: Decodable { let id: String; let members: [ReportMember] }
private struct ShareReportResponse: Decodable { let shareReport: ReportMembersResult }
private struct UpdateShareRoleResponse: Decodable { let updateReportShareRole: ReportMembersResult }
private struct UnshareReportResponse: Decodable { let unshareReport: ReportMembersResult }
private struct LeaveSharedReportResponse: Decodable { let leaveSharedReport: Bool }

// MARK: - ViewModel

@MainActor
@Observable
final class ReportDetailViewModel {
    var report: Report?
    var isLoading = false
    var error: String?

    private let client = GraphQLClient.shared

    func loadReport(id: String, token: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            struct Vars: Encodable { let id: String }
            let response: ReportResponse = try await client.perform(
                query: getReportQuery,
                variables: Vars(id: id),
                token: token
            )
            report = response.report
            Task { await loadSharingInfo(id: id, token: token) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSharingInfo(id: String, token: String) async {
        guard report != nil else { return }
        do {
            struct Vars: Encodable { let id: String }
            let response: ReportSharingResponse = try await client.perform(
                query: getReportSharingQuery,
                variables: Vars(id: id),
                token: token
            )
            if let info = response.report, var r = report {
                r.myRole = info.myRole
                r.members = info.members
                report = r
            }
        } catch {
            // Server may not support sharing yet — fail silently
        }
    }

    func renameReport(id: String, newTitle: String, token: String) async throws {
        struct Input: Encodable { let id: String; let title: String }
        struct Vars: Encodable { let input: Input }
        let response: UpdateReportResponse = try await client.perform(
            query: updateReportMutation,
            variables: Vars(input: Input(id: id, title: newTitle)),
            token: token
        )
        if var updated = report {
            updated.title = response.updateReport.title
            updated.updatedAt = response.updateReport.updatedAt
            report = updated
        }
    }

    func lockReport(id: String, token: String) async throws {
        struct Vars: Encodable { let id: String }
        let response: LockReportResponse = try await client.perform(
            query: lockReportMutation,
            variables: Vars(id: id),
            token: token
        )
        if var updated = report { updated.isLocked = response.lockReport.isLocked; report = updated }
    }

    func unlockReport(id: String, token: String) async throws {
        struct Vars: Encodable { let id: String }
        let response: UnlockReportResponse = try await client.perform(
            query: unlockReportMutation,
            variables: Vars(id: id),
            token: token
        )
        if var updated = report { updated.isLocked = response.unlockReport.isLocked; report = updated }
    }

    func deleteReport(id: String, token: String) async throws {
        struct Vars: Encodable { let id: String }
        struct DeleteResponse: Decodable { let deleteReport: Bool }
        let _: DeleteResponse = try await client.perform(
            query: deleteReportMutation,
            variables: Vars(id: id),
            token: token
        )
    }

    func createTransaction(reportId: String, type: String, amount: Double, description: String, category: String, date: String, token: String) async throws {
        struct Input: Encodable {
            let reportId: String; let type: String; let amount: Double
            let description: String; let category: String; let date: String
        }
        struct Vars: Encodable { let input: Input }
        let response: CreateTransactionResponse = try await client.perform(
            query: createTransactionMutation,
            variables: Vars(input: Input(reportId: reportId, type: type, amount: amount, description: description, category: category, date: date)),
            token: token
        )
        if var updated = report {
            var txns = updated.transactions ?? []
            txns.append(response.createTransaction)
            updated.transactions = txns
            report = updated
        }
    }

    func updateTransaction(id: String, type: String, amount: Double, description: String, category: String, date: String, token: String) async throws {
        struct Input: Encodable {
            let id: String; let type: String; let amount: Double
            let description: String; let category: String; let date: String
        }
        struct Vars: Encodable { let input: Input }
        let response: UpdateTransactionResponse = try await client.perform(
            query: updateTransactionMutation,
            variables: Vars(input: Input(id: id, type: type, amount: amount, description: description, category: category, date: date)),
            token: token
        )
        if var updated = report {
            updated.transactions = updated.transactions?.map { $0.id == id ? response.updateTransaction : $0 }
            report = updated
        }
    }

    func deleteTransaction(id: String, token: String) async throws {
        struct Vars: Encodable { let id: String }
        let _: DeleteTransactionResponse = try await client.perform(
            query: deleteTransactionMutation,
            variables: Vars(id: id),
            token: token
        )
        if var updated = report {
            updated.transactions = updated.transactions?.filter { $0.id != id }
            report = updated
        }
    }

    func shareReport(reportId: String, email: String, role: ReportRole, token: String) async throws {
        struct Input: Encodable { let reportId: String; let email: String; let role: String }
        struct Vars: Encodable { let input: Input }
        let response: ShareReportResponse = try await client.perform(
            query: shareReportMutation,
            variables: Vars(input: Input(reportId: reportId, email: email, role: role.rawValue)),
            token: token
        )
        if var r = report { r.members = response.shareReport.members; report = r }
    }

    func updateMemberRole(shareId: String, role: ReportRole, token: String) async throws {
        struct Input: Encodable { let id: String; let role: String }
        struct Vars: Encodable { let input: Input }
        let response: UpdateShareRoleResponse = try await client.perform(
            query: updateReportShareRoleMutation,
            variables: Vars(input: Input(id: shareId, role: role.rawValue)),
            token: token
        )
        if var r = report { r.members = response.updateReportShareRole.members; report = r }
    }

    func unshareReport(shareId: String, token: String) async throws {
        struct Vars: Encodable { let id: String }
        let response: UnshareReportResponse = try await client.perform(
            query: unshareReportMutation,
            variables: Vars(id: shareId),
            token: token
        )
        if var r = report { r.members = response.unshareReport.members; report = r }
    }

    func leaveSharedReport(reportId: String, token: String) async throws {
        struct Vars: Encodable { let reportId: String }
        let _: LeaveSharedReportResponse = try await client.perform(
            query: leaveSharedReportMutation,
            variables: Vars(reportId: reportId),
            token: token
        )
    }
}
