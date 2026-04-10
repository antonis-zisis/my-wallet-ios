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

// MARK: - Response types

private struct ReportResponse: Decodable { let report: Report? }
private struct UpdateReportResult: Decodable { let id: String; let title: String; let updatedAt: String }
private struct UpdateReportResponse: Decodable { let updateReport: UpdateReportResult }
private struct LockResult: Decodable { let id: String; let isLocked: Bool }
private struct LockReportResponse: Decodable { let lockReport: LockResult }
private struct UnlockReportResponse: Decodable { let unlockReport: LockResult }

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
        } catch {
            self.error = error.localizedDescription
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
}
