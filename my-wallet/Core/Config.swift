import Foundation

enum Config {
    // MARK: - Supabase
    static let supabaseURL = "https://tagrwphjyathaiovapqn.supabase.co"
    static let supabaseAnonKey = Secrets.supabaseAnonKey

    // MARK: - API
    static let graphQLEndpoint = URL(string: "https://my-wallet-backend-883133501816.europe-west1.run.app/graphql")!
}
