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

private let getSubscriptionsQuery = """
  query GetActiveSubscriptions {
    subscriptions(active: true) {
      items {
        id
        name
        amount
        billingCycle
        isActive
        startDate
        monthlyCost
      }
      totalCount
    }
  }
"""

private let getNetWorthSnapshotsQuery = """
  query GetLatestNetWorthSnapshot {
    netWorthSnapshots(page: 1, pageSize: 1) {
      items {
        id
        title
        totalAssets
        totalLiabilities
        netWorth
        createdAt
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

private struct SubscriptionsResult: Decodable {
    let items: [Subscription]
    let totalCount: Int
}

private struct SubscriptionsResponse: Decodable {
    let subscriptions: SubscriptionsResult
}

private struct NetWorthSnapshotsResult: Decodable {
    let items: [NetWorthSnapshot]
}

private struct NetWorthSnapshotsResponse: Decodable {
    let netWorthSnapshots: NetWorthSnapshotsResult
}

// MARK: - ViewModel

@MainActor
@Observable
final class DashboardViewModel {
    var isLoading = false
    var totalReportsCount: Int?
    var currentReport: Report?
    var previousReport: Report?
    var subscriptions: [Subscription] = []
    var latestSnapshot: NetWorthSnapshot?
    var error: String?

    private let client = GraphQLClient.shared

    func loadData(token: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            // Fetch reports list and subscriptions concurrently
            struct ReportVars: Encodable { let page: Int; let pageSize: Int }
            async let reportsResp: ReportsResponse = client.perform(
                query: getReportsQuery,
                variables: ReportVars(page: 1, pageSize: 2),
                token: token
            )
            async let subsResp: SubscriptionsResponse = client.perform(
                query: getSubscriptionsQuery,
                token: token
            )
            async let snapshotResp: NetWorthSnapshotsResponse = client.perform(
                query: getNetWorthSnapshotsQuery,
                token: token
            )

            let (reports, subs, snapshots) = try await (reportsResp, subsResp, snapshotResp)
            totalReportsCount = reports.reports.totalCount
            subscriptions = subs.subscriptions.items
            latestSnapshot = snapshots.netWorthSnapshots.items.first

            let items = reports.reports.items
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

