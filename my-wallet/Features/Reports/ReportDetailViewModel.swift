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

private struct ReportResponse: Decodable {
    let report: Report?
}

// MARK: - ViewModel

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
}
