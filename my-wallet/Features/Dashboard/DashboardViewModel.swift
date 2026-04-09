import Foundation

// MARK: - GraphQL Queries

private let getReportsQuery = """
  query GetReports($page: Int, $pageSize: Int) {
    reports(page: $page, pageSize: $pageSize) {
      items { id }
      totalCount
    }
  }
"""

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

// MARK: - Response types

private struct ReportStub: Decodable { let id: String }

private struct ReportsResult: Decodable {
    let items: [ReportStub]
    let totalCount: Int
}

private struct ReportsResponse: Decodable {
    let reports: ReportsResult
}

private struct ReportResponse: Decodable {
    let report: Report?
}

// MARK: - ViewModel

@Observable
final class DashboardViewModel {
    var isLoading = false
    var totalReportsCount: Int?
    var currentReport: Report?
    var previousReport: Report?
    var error: String?

    private let client = GraphQLClient.shared

    func loadData(token: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Fetch first 2 report stubs + total count
            struct Vars: Encodable { let page: Int; let pageSize: Int }
            let reportsResp: ReportsResponse = try await client.perform(
                query: getReportsQuery,
                variables: Vars(page: 1, pageSize: 2),
                token: token
            )
            totalReportsCount = reportsResp.reports.totalCount

            let items = reportsResp.reports.items

            // Fetch current and previous report concurrently
            async let current = fetchReport(id: items[safe: 0]?.id, token: token)
            async let previous = fetchReport(id: items[safe: 1]?.id, token: token)
            (currentReport, previousReport) = try await (current, previous)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func fetchReport(id: String?, token: String) async throws -> Report? {
        guard let id else { return nil }
        struct Vars: Encodable { let id: String }
        let response: ReportResponse = try await client.perform(
            query: getReportQuery,
            variables: Vars(id: id),
            token: token
        )
        return response.report
    }
}
