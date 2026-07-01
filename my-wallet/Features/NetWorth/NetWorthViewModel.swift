import Foundation

// MARK: - GraphQL

private let getNetWorthSnapshotsQuery = """
  query GetNetWorthSnapshots($page: Int, $pageSize: Int) {
    netWorthSnapshots(page: $page, pageSize: $pageSize) {
      items {
        id
        title
        snapshotDate
        totalAssets
        totalLiabilities
        netWorth
        previousSnapshot {
          netWorth
        }
        createdAt
      }
      totalCount
    }
  }
"""

private let getNetWorthSnapshotQuery = """
  query GetNetWorthSnapshot($id: ID!) {
    netWorthSnapshot(id: $id) {
      id
      title
      snapshotDate
      totalAssets
      totalLiabilities
      netWorth
      entries {
        id
        type
        label
        amount
        category
        notes
      }
      previousSnapshot {
        totalAssets
        totalLiabilities
        netWorth
        entries {
          type
          label
          amount
          category
          notes
        }
      }
      createdAt
      updatedAt
    }
  }
"""

private let createNetWorthSnapshotMutation = """
  mutation CreateNetWorthSnapshot($input: CreateNetWorthSnapshotInput!) {
    createNetWorthSnapshot(input: $input) {
      id
      title
      snapshotDate
      totalAssets
      totalLiabilities
      netWorth
      previousSnapshot {
        netWorth
      }
      createdAt
    }
  }
"""

private let updateNetWorthSnapshotMutation = """
  mutation UpdateNetWorthSnapshot($id: ID!, $input: UpdateNetWorthSnapshotInput!) {
    updateNetWorthSnapshot(id: $id, input: $input) {
      id
      title
      snapshotDate
      totalAssets
      totalLiabilities
      netWorth
      entries {
        id
        type
        label
        amount
        category
        notes
      }
      previousSnapshot {
        totalAssets
        totalLiabilities
        netWorth
        entries {
          type
          label
          amount
          category
          notes
        }
      }
      createdAt
      updatedAt
    }
  }
"""

private let deleteNetWorthSnapshotMutation = """
  mutation DeleteNetWorthSnapshot($id: ID!) {
    deleteNetWorthSnapshot(id: $id)
  }
"""

// MARK: - Response wrappers

private struct NetWorthSnapshotsResult: Decodable {
    let items: [NetWorthSnapshot]
    let totalCount: Int
}

private struct NetWorthSnapshotsResponse: Decodable {
    let netWorthSnapshots: NetWorthSnapshotsResult
}

private struct NetWorthSnapshotDetailResponse: Decodable {
    let netWorthSnapshot: NetWorthSnapshot
}

private struct CreateNetWorthSnapshotResponse: Decodable {
    let createNetWorthSnapshot: NetWorthSnapshot
}

private struct UpdateNetWorthSnapshotResponse: Decodable {
    let updateNetWorthSnapshot: NetWorthSnapshot
}

private struct DeleteNetWorthSnapshotResponse: Decodable {
    let deleteNetWorthSnapshot: Bool
}

// MARK: - Input types

struct NetWorthEntryInput: Encodable {
    let type: String
    let label: String
    let amount: Double
    let category: String
    let notes: String?
}

struct CreateNetWorthSnapshotInput: Encodable {
    let title: String
    let snapshotDate: String
    let entries: [NetWorthEntryInput]
}

struct UpdateNetWorthSnapshotInput: Encodable {
    let title: String
    let snapshotDate: String
    let entries: [NetWorthEntryInput]
}

// MARK: - Categories

let assetCategories = ["Savings", "Investments", "Real Estate", "Vehicle", "Other"]
let liabilityCategories = ["Mortgage", "Car Loan", "Student Loan", "Credit Card", "Personal Loan", "Other"]

// MARK: - ViewModel

@MainActor
@Observable
final class NetWorthViewModel {
    var snapshots: [NetWorthSnapshot] = []
    var isLoading = false
    var error = false
    var totalCount = 0
    var isMutating = false

    var searchText = ""
    var sortOption: NetWorthSortOption = .date

    private let client = GraphQLClient.shared

    /// Snapshots filtered by the search query and ordered by the selected sort
    /// option. Mirrors the web list controls; the trend chart keeps using the
    /// full unfiltered `snapshots`.
    var visibleSnapshots: [NetWorthSnapshot] {
        var items = snapshots

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            items = items.filter { $0.title.lowercased().contains(query) }
        }

        switch sortOption {
        case .date:
            items.sort { $0.parsedSnapshotDate > $1.parsedSnapshotDate }
        case .changeHighLow:
            items.sort { Self.compareByDelta($0, $1, ascending: false) }
        case .changeLowHigh:
            items.sort { Self.compareByDelta($0, $1, ascending: true) }
        }

        return items
    }

    /// Orders two snapshots by their change in net worth. Snapshots without a
    /// previous snapshot (no delta) always sort to the bottom, falling back to a
    /// most-recent-first tie-break.
    private static func compareByDelta(
        _ left: NetWorthSnapshot,
        _ right: NetWorthSnapshot,
        ascending: Bool
    ) -> Bool {
        switch (left.delta, right.delta) {
        case let (l?, r?):
            if l == r { return left.parsedSnapshotDate > right.parsedSnapshotDate }
            return ascending ? l < r : l > r
        case (nil, _?): return false
        case (_?, nil): return true
        case (nil, nil): return left.parsedSnapshotDate > right.parsedSnapshotDate
        }
    }

    func load(token: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = false
        defer { isLoading = false }

        struct Vars: Encodable { let page: Int; let pageSize: Int }
        do {
            let response: NetWorthSnapshotsResponse = try await client.perform(
                query: getNetWorthSnapshotsQuery,
                variables: Vars(page: 1, pageSize: 50),
                token: token
            )
            snapshots = response.netWorthSnapshots.items
            totalCount = response.netWorthSnapshots.totalCount
        } catch {
            self.error = true
        }
    }

    func loadDetail(id: String, token: String) async throws -> NetWorthSnapshot {
        struct Vars: Encodable { let id: String }
        let response: NetWorthSnapshotDetailResponse = try await client.perform(
            query: getNetWorthSnapshotQuery,
            variables: Vars(id: id),
            token: token
        )
        return response.netWorthSnapshot
    }

    func create(input: CreateNetWorthSnapshotInput, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let input: CreateNetWorthSnapshotInput }
        do {
            let response: CreateNetWorthSnapshotResponse = try await client.perform(
                query: createNetWorthSnapshotMutation,
                variables: Vars(input: input),
                token: token
            )
            snapshots.insert(response.createNetWorthSnapshot, at: 0)
            totalCount += 1
        } catch {}
    }

    func update(id: String, input: UpdateNetWorthSnapshotInput, token: String) async throws -> NetWorthSnapshot {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let id: String; let input: UpdateNetWorthSnapshotInput }
        let response: UpdateNetWorthSnapshotResponse = try await client.perform(
            query: updateNetWorthSnapshotMutation,
            variables: Vars(id: id, input: input),
            token: token
        )
        let updated = response.updateNetWorthSnapshot
        if let index = snapshots.firstIndex(where: { $0.id == id }) {
            snapshots[index] = updated
        }
        return updated
    }

    func delete(id: String, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let id: String }
        do {
            let _: DeleteNetWorthSnapshotResponse = try await client.perform(
                query: deleteNetWorthSnapshotMutation,
                variables: Vars(id: id),
                token: token
            )
            snapshots.removeAll { $0.id == id }
            totalCount -= 1
        } catch {}
    }
}
