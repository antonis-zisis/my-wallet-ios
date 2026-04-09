import Supabase

// Shared Supabase client. Sessions are persisted in the Keychain automatically.
let supabase = SupabaseClient(
    supabaseURL: URL(string: Config.supabaseURL)!,
    supabaseKey: Config.supabaseAnonKey
)
