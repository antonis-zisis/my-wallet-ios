import Foundation

// MARK: - GraphQL

private let PAGE_SIZE = 20

private let createReportMutation = """
  mutation CreateReport($input: CreateReportInput!) {
    createReport(input: $input) {
      id
      title
      isLocked
      transactionCount
      netBalance
      createdAt
      updatedAt
    }
  }
"""

private let getReportsQuery = """
  query GetReports($page: Int, $pageSize: Int, $search: String, $sortBy: ReportSortField, $sortOrder: SortOrder) {
    reports(page: $page, pageSize: $pageSize, search: $search, sortBy: $sortBy, sortOrder: $sortOrder) {
      items {
        id
        title
        isLocked
        transactionCount
        netBalance
        createdAt
        updatedAt
      }
      totalCount
    }
  }
"""

private struct CreateReportResponse: Decodable {
    let createReport: Report
}

private struct ReportsResult: Decodable {
    let items: [Report]
    let totalCount: Int
}

private struct ReportsResponse: Decodable {
    let reports: ReportsResult
}

// MARK: - ViewModel

@MainActor
@Observable
final class ReportsViewModel {
    var items: [Report] = []
    var isLoading = false
    var isLoadingMore = false
    var hasMore = false
    var error: String?

    var searchText = ""
    var sortOption: ReportSortOption = .newest

    private var currentPage = 0
    private(set) var totalCount = 0
    private let client = GraphQLClient.shared

    /// Whether the user is currently filtering by a non-empty search term.
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private struct Vars: Encodable {
        let page: Int
        let pageSize: Int
        let search: String?
        let sortBy: String
        let sortOrder: String
    }

    private func makeVars(page: Int) -> Vars {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        return Vars(
            page: page,
            pageSize: PAGE_SIZE,
            search: trimmed.isEmpty ? nil : trimmed,
            sortBy: sortOption.sortBy,
            sortOrder: sortOption.sortOrder
        )
    }

    /// Re-fetch from the first page using the current search term and sort option.
    func reload(token: String) async {
        await loadInitial(token: token)
    }

    func loadInitial(token: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let response: ReportsResponse = try await client.perform(
                query: getReportsQuery,
                variables: makeVars(page: 1),
                token: token
            )
            items = response.reports.items
            totalCount = response.reports.totalCount
            currentPage = 1
            hasMore = items.count < totalCount
        } catch is CancellationError {
            // Task was cancelled by SwiftUI (e.g. tab switch) — don't surface this as a user-visible error
        } catch {
            self.error = error.localizedDescription
        }
    }

    func update(report: Report) {
        guard let index = items.firstIndex(where: { $0.id == report.id }) else { return }
        items[index] = report
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        totalCount -= 1
    }

    func createReport(title: String, token: String) async throws {
        struct Input: Encodable { let title: String }
        struct Vars: Encodable { let input: Input }
        let response: CreateReportResponse = try await client.perform(
            query: createReportMutation,
            variables: Vars(input: Input(title: title)),
            token: token
        )
        items.insert(response.createReport, at: 0)
        totalCount += 1
    }

    func loadMore(token: String) async {
        guard !isLoadingMore, !isLoading, hasMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }

        do {
            let nextPage = currentPage + 1
            let response: ReportsResponse = try await client.perform(
                query: getReportsQuery,
                variables: makeVars(page: nextPage),
                token: token
            )
            items.append(contentsOf: response.reports.items)
            currentPage = nextPage
            hasMore = items.count < totalCount
        } catch {
            // Pagination errors are silent — the user can scroll up and retry via pull-to-refresh
        }
    }
}
