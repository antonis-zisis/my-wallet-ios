import Foundation

enum Config {
    // MARK: - Supabase
    // Get these from https://app.supabase.com/project/_/settings/api
    static let supabaseURL = "https://tagrwphjyathaiovapqn.supabase.co"
    static let supabaseAnonKey = "sb_publishable_pKOAYfhVLPrrM7kWK08SdQ_am_Lb60A"

    // MARK: - API
    // Simulator can use localhost. Physical device needs your Mac's local IP.
    static let graphQLEndpoint = URL(string: "https://my-wallet-backend-883133501816.europe-west1.run.app/graphql")!
}
