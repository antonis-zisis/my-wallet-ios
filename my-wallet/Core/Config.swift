import Foundation

enum Config {
    // MARK: - Supabase
    // Get these from https://app.supabase.com/project/_/settings/api
    static let supabaseURL = "https://YOUR_PROJECT_REF.supabase.co"
    static let supabaseAnonKey = "YOUR_ANON_KEY"

    // MARK: - API
    // Simulator can use localhost. Physical device needs your Mac's local IP.
    static let graphQLEndpoint = URL(string: "http://localhost:4000/graphql")!
}
