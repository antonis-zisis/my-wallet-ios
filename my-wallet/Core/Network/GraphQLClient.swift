import Foundation

// MARK: - Wire types

private struct GraphQLRequest<V: Encodable>: Encodable {
    let query: String
    let variables: V
}

private struct GraphQLResponse<T: Decodable>: Decodable {
    struct GQLError: Decodable { let message: String }
    let data: T?
    let errors: [GQLError]?
}

// MARK: - Errors

enum GraphQLError: LocalizedError {
    case server(String)
    case noData

    var errorDescription: String? {
        switch self {
        case .server(let msg): return msg
        case .noData: return "No data returned from server."
        }
    }
}

// MARK: - Client

struct GraphQLClient {
    static let shared = GraphQLClient()
    private init() {}

    private let session = URLSession.shared
    private let decoder = JSONDecoder()

    /// Performs a GraphQL operation with typed variables.
    func perform<T: Decodable, V: Encodable>(
        query: String,
        variables: V,
        token: String
    ) async throws -> T {
        var request = URLRequest(url: Config.graphQLEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            GraphQLRequest(query: query, variables: variables)
        )

        let (data, _) = try await session.data(for: request)
        let response = try decoder.decode(GraphQLResponse<T>.self, from: data)

        if let errors = response.errors, let first = errors.first {
            throw GraphQLError.server(first.message)
        }
        guard let result = response.data else {
            throw GraphQLError.noData
        }
        return result
    }

    /// Performs a GraphQL operation with no variables.
    func perform<T: Decodable>(query: String, token: String) async throws -> T {
        struct NoVariables: Encodable {}
        return try await perform(query: query, variables: NoVariables(), token: token)
    }
}
