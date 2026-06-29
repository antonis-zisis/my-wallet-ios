import Foundation

// MARK: - GraphQL Queries

private let getContractsQuery = """
  query GetContracts($page: Int, $pageSize: Int, $sortBy: ContractSortField, $sortOrder: SortOrder) {
    contracts(page: $page, pageSize: $pageSize, sortBy: $sortBy, sortOrder: $sortOrder) {
      items {
        id
        category
        provider
        plan
        startDate
        endDate
        cost
        isExpired
      }
      totalCount
    }
  }
"""

// MARK: - GraphQL Mutations

private let createContractMutation = """
  mutation CreateContract($input: CreateContractInput!) {
    createContract(input: $input) {
      id
      category
      provider
      plan
      startDate
      endDate
      cost
      isExpired
    }
  }
"""

private let updateContractMutation = """
  mutation UpdateContract($input: UpdateContractInput!) {
    updateContract(input: $input) {
      id
      category
      provider
      plan
      startDate
      endDate
      cost
      isExpired
    }
  }
"""

private let deleteContractMutation = """
  mutation DeleteContract($id: ID!) {
    deleteContract(id: $id)
  }
"""

// MARK: - Response types

private struct ContractsResult: Decodable {
    let items: [Contract]
    let totalCount: Int
}

private struct ContractsResponse: Decodable {
    let contracts: ContractsResult
}

private struct CreateContractResponse: Decodable {
    let createContract: Contract
}

private struct UpdateContractResponse: Decodable {
    let updateContract: Contract
}

private struct DeleteContractResponse: Decodable {
    let deleteContract: Bool
}

// MARK: - Input types

struct CreateContractInput: Encodable {
    let category: String
    let provider: String
    let plan: String?
    let startDate: String?
    let endDate: String?
    let cost: Double?
}

struct UpdateContractInput: Encodable {
    let id: String
    let category: String
    let provider: String
    let plan: String?
    let startDate: String?
    let endDate: String?
    let cost: Double?
}

// MARK: - ViewModel

@MainActor
@Observable
final class ContractsViewModel {
    var contracts: [Contract] = []
    var isLoading = false
    var error = false
    var isMutating = false

    var searchText = ""
    var sortBy: ContractSortField = .endDate

    private let client = GraphQLClient.shared

    var visibleContracts: [Contract] {
        var items = contracts

        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        if !query.isEmpty {
            items = items.filter { $0.provider.lowercased().contains(query) }
        }

        switch sortBy {
        case .provider:
            items.sort { $0.provider.localizedCaseInsensitiveCompare($1.provider) == .orderedAscending }
        case .endDate:
            items.sort { left, right in
                switch (left.endDate, right.endDate) {
                case let (l?, r?): return Contract.parseDate(l) < Contract.parseDate(r)
                case (nil, _?):    return false
                case (_?, nil):    return true
                case (nil, nil):   return left.provider.localizedCaseInsensitiveCompare(right.provider) == .orderedAscending
                }
            }
        }

        return items
    }

    func load(token: String) async {
        guard !isLoading else { return }
        isLoading = true
        error = false
        defer { isLoading = false }

        struct Vars: Encodable {
            let page: Int
            let pageSize: Int
            let sortBy: String
            let sortOrder: String
        }
        do {
            let response: ContractsResponse = try await client.perform(
                query: getContractsQuery,
                variables: Vars(page: 1, pageSize: 100, sortBy: "END_DATE", sortOrder: "ASC"),
                token: token
            )
            contracts = response.contracts.items
        } catch {
            self.error = true
        }
    }

    func create(input: CreateContractInput, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let input: CreateContractInput }
        do {
            let response: CreateContractResponse = try await client.perform(
                query: createContractMutation,
                variables: Vars(input: input),
                token: token
            )
            contracts.insert(response.createContract, at: 0)
        } catch {}
    }

    func update(input: UpdateContractInput, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let input: UpdateContractInput }
        do {
            let response: UpdateContractResponse = try await client.perform(
                query: updateContractMutation,
                variables: Vars(input: input),
                token: token
            )
            let updated = response.updateContract
            if let idx = contracts.firstIndex(where: { $0.id == updated.id }) {
                contracts[idx] = updated
            }
        } catch {}
    }

    func delete(id: String, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let id: String }
        do {
            let _: DeleteContractResponse = try await client.perform(
                query: deleteContractMutation,
                variables: Vars(id: id),
                token: token
            )
            contracts.removeAll { $0.id == id }
        } catch {}
    }
}
