import Foundation

// MARK: - GraphQL

private let getNetWorthSnapshotsQuery = """
  query GetNetWorthSnapshots($page: Int, $pageSize: Int) {
    netWorthSnapshots(page: $page, pageSize: $pageSize) {
      items {
        id
        title
        totalAssets
        totalLiabilities
        netWorth
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
      totalAssets
      totalLiabilities
      netWorth
      entries {
        id
        type
        label
        amount
        category
      }
      createdAt
    }
  }
"""

private let createNetWorthSnapshotMutation = """
  mutation CreateNetWorthSnapshot($input: CreateNetWorthSnapshotInput!) {
    createNetWorthSnapshot(input: $input) {
      id
      title
      totalAssets
      totalLiabilities
      netWorth
      createdAt
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

private struct DeleteNetWorthSnapshotResponse: Decodable {
    let deleteNetWorthSnapshot: Bool
}

// MARK: - Input types

struct NetWorthEntryInput: Encodable {
    let type: String
    let label: String
    let amount: Double
    let category: String
}

struct CreateNetWorthSnapshotInput: Encodable {
    let title: String
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

    private let client = GraphQLClient.shared

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
