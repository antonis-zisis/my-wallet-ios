import Foundation

// MARK: - GraphQL Queries

private let getSubscriptionsQuery = """
  query GetSubscriptions($page: Int, $pageSize: Int, $active: Boolean) {
    subscriptions(page: $page, pageSize: $pageSize, active: $active) {
      items {
        id
        name
        amount
        billingCycle
        isActive
        startDate
        endDate
        cancelledAt
        monthlyCost
        createdAt
        updatedAt
      }
      totalCount
    }
  }
"""

// MARK: - GraphQL Mutations

private let createSubscriptionMutation = """
  mutation CreateSubscription($input: CreateSubscriptionInput!) {
    createSubscription(input: $input) {
      id
      name
      amount
      billingCycle
      isActive
      startDate
      endDate
      cancelledAt
      monthlyCost
      createdAt
      updatedAt
    }
  }
"""

private let updateSubscriptionMutation = """
  mutation UpdateSubscription($input: UpdateSubscriptionInput!) {
    updateSubscription(input: $input) {
      id
      name
      amount
      billingCycle
      isActive
      startDate
      endDate
      cancelledAt
      monthlyCost
      createdAt
      updatedAt
    }
  }
"""

private let cancelSubscriptionMutation = """
  mutation CancelSubscription($id: ID!) {
    cancelSubscription(id: $id) {
      id
      isActive
      cancelledAt
      endDate
    }
  }
"""

private let resumeSubscriptionMutation = """
  mutation ResumeSubscription($input: ResumeSubscriptionInput!) {
    resumeSubscription(input: $input) {
      id
      name
      amount
      billingCycle
      isActive
      startDate
      endDate
      cancelledAt
      monthlyCost
      createdAt
      updatedAt
    }
  }
"""

private let deleteSubscriptionMutation = """
  mutation DeleteSubscription($id: ID!) {
    deleteSubscription(id: $id)
  }
"""

// MARK: - Response types

private struct SubscriptionsResult: Decodable {
    let items: [Subscription]
    let totalCount: Int
}

private struct SubscriptionsResponse: Decodable {
    let subscriptions: SubscriptionsResult
}

private struct CreateSubscriptionResponse: Decodable {
    let createSubscription: Subscription
}

private struct UpdateSubscriptionResponse: Decodable {
    let updateSubscription: Subscription
}

private struct CancelledFields: Decodable {
    let id: String
    let isActive: Bool
    let cancelledAt: String?
    let endDate: String?
}

private struct CancelSubscriptionResponse: Decodable {
    let cancelSubscription: CancelledFields
}

private struct ResumeSubscriptionResponse: Decodable {
    let resumeSubscription: Subscription
}

private struct DeleteSubscriptionResponse: Decodable {
    let deleteSubscription: Bool
}

// MARK: - Input types

struct CreateSubscriptionInput: Encodable {
    let name: String
    let amount: Double
    let billingCycle: String
    let startDate: String
}

struct UpdateSubscriptionInput: Encodable {
    let id: String
    let name: String
    let amount: Double
    let billingCycle: String
    let startDate: String
}

struct ResumeSubscriptionInput: Encodable {
    let id: String
    let startDate: String
    let amount: Double
    let billingCycle: String
}

// MARK: - ViewModel

@MainActor
@Observable
final class SubscriptionsViewModel {
    var activeSubscriptions: [Subscription] = []
    var inactiveSubscriptions: [Subscription] = []
    var isLoadingActive = false
    var isLoadingInactive = false
    var activeError = false
    var inactiveError = false
    var showInactive = false

    var isMutating = false

    var totalMonthlyCost: Double {
        activeSubscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    var totalYearlyCost: Double {
        totalMonthlyCost * 12
    }

    private let client = GraphQLClient.shared

    func loadActive(token: String) async {
        guard !isLoadingActive else { return }
        isLoadingActive = true
        activeError = false
        defer { isLoadingActive = false }

        struct Vars: Encodable { let active: Bool }
        do {
            let response: SubscriptionsResponse = try await client.perform(
                query: getSubscriptionsQuery,
                variables: Vars(active: true),
                token: token
            )
            activeSubscriptions = response.subscriptions.items
        } catch {
            activeError = true
        }
    }

    func loadInactive(token: String) async {
        guard !isLoadingInactive else { return }
        isLoadingInactive = true
        inactiveError = false
        defer { isLoadingInactive = false }

        struct Vars: Encodable { let active: Bool }
        do {
            let response: SubscriptionsResponse = try await client.perform(
                query: getSubscriptionsQuery,
                variables: Vars(active: false),
                token: token
            )
            inactiveSubscriptions = response.subscriptions.items
        } catch {
            inactiveError = true
        }
    }

    func loadAll(token: String) async {
        await loadActive(token: token)
        await loadInactive(token: token)
    }

    func create(input: CreateSubscriptionInput, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let input: CreateSubscriptionInput }
        do {
            let response: CreateSubscriptionResponse = try await client.perform(
                query: createSubscriptionMutation,
                variables: Vars(input: input),
                token: token
            )
            activeSubscriptions.insert(response.createSubscription, at: 0)
        } catch {}
    }

    func update(input: UpdateSubscriptionInput, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let input: UpdateSubscriptionInput }
        do {
            let response: UpdateSubscriptionResponse = try await client.perform(
                query: updateSubscriptionMutation,
                variables: Vars(input: input),
                token: token
            )
            let updated = response.updateSubscription
            if let idx = activeSubscriptions.firstIndex(where: { $0.id == updated.id }) {
                activeSubscriptions[idx] = updated
            }
        } catch {}
    }

    func cancel(id: String, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let id: String }
        do {
            let response: CancelSubscriptionResponse = try await client.perform(
                query: cancelSubscriptionMutation,
                variables: Vars(id: id),
                token: token
            )
            let fields = response.cancelSubscription
            if let idx = activeSubscriptions.firstIndex(where: { $0.id == fields.id }) {
                let old = activeSubscriptions[idx]
                let updated = Subscription(
                    id: old.id,
                    name: old.name,
                    amount: old.amount,
                    billingCycle: old.billingCycle,
                    isActive: fields.isActive,
                    startDate: old.startDate,
                    endDate: fields.endDate,
                    cancelledAt: fields.cancelledAt,
                    monthlyCost: old.monthlyCost
                )
                activeSubscriptions[idx] = updated
            }
        } catch {}
    }

    func resume(input: ResumeSubscriptionInput, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let input: ResumeSubscriptionInput }
        do {
            let response: ResumeSubscriptionResponse = try await client.perform(
                query: resumeSubscriptionMutation,
                variables: Vars(input: input),
                token: token
            )
            let resumed = response.resumeSubscription
            inactiveSubscriptions.removeAll { $0.id == resumed.id }
            activeSubscriptions.insert(resumed, at: 0)
        } catch {}
    }

    func delete(id: String, token: String) async {
        isMutating = true
        defer { isMutating = false }
        struct Vars: Encodable { let id: String }
        do {
            let _: DeleteSubscriptionResponse = try await client.perform(
                query: deleteSubscriptionMutation,
                variables: Vars(id: id),
                token: token
            )
            activeSubscriptions.removeAll { $0.id == id }
            inactiveSubscriptions.removeAll { $0.id == id }
        } catch {}
    }
}
