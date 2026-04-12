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

private let getReportsSummaryQuery = """
  query GetReportsSummary {
    reports(page: 1, pageSize: 12) {
      items {
        id
        title
        transactions {
          type
          amount
        }
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

fileprivate struct SummaryTransaction: Decodable {
    let type: String
    let amount: Double
}

struct ReportSummaryItem: Decodable, Identifiable {
    let id: String
    let title: String
    let totalIncome: Double
    let totalExpenses: Double

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        let transactions = try container.decodeIfPresent([SummaryTransaction].self, forKey: .transactions) ?? []
        totalIncome = transactions.filter { $0.type == "INCOME" }.reduce(0) { $0 + $1.amount }
        totalExpenses = transactions.filter { $0.type == "EXPENSE" }.reduce(0) { $0 + $1.amount }
    }

    private enum CodingKeys: String, CodingKey { case id, title, transactions }
}

private struct ReportsSummaryResult: Decodable { let items: [ReportSummaryItem] }
private struct ReportsSummaryResponse: Decodable { let reports: ReportsSummaryResult }

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
    var reportSummaries: [ReportSummaryItem] = []
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
            // Sequential await avoids the Swift 6 warning "Main actor-isolated
            // conformance cannot be used in nonisolated context" that fires when
            // async let creates nonisolated child tasks calling Decodable inits
            // on types whose conformances are inferred as @MainActor.
            // Direct await on a @MainActor function does not cross that boundary.
            struct ReportVars: Encodable { let page: Int; let pageSize: Int }
            let reports: ReportsResponse = try await client.perform(
                query: getReportsQuery,
                variables: ReportVars(page: 1, pageSize: 2),
                token: token
            )
            let summaries: ReportsSummaryResponse = try await client.perform(
                query: getReportsSummaryQuery,
                token: token
            )
            let subs: SubscriptionsResponse = try await client.perform(
                query: getSubscriptionsQuery,
                token: token
            )
            let snapshots: NetWorthSnapshotsResponse = try await client.perform(
                query: getNetWorthSnapshotsQuery,
                token: token
            )

            totalReportsCount = reports.reports.totalCount
            reportSummaries = summaries.reports.items.reversed()
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
