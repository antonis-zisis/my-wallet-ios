# my-wallet iOS

iOS companion app for the my-wallet web application. Goal is to mirror the web functionality feature-by-feature.

## Related Projects

| Project | Path | Purpose |
|---------|------|---------|
| Web app | `../my-wallet/apps/web` | React/TypeScript frontend (reference implementation) |
| Server  | `../my-wallet/apps/server` | Node/Apollo GraphQL API + Prisma/PostgreSQL |

## Tech Stack

- **Swift 6** with **SwiftUI** (iOS 17+, targets iOS 26.2)
- **Xcode 16+** — uses `PBXFileSystemSynchronizedRootGroup`, so new Swift files added to the `my-wallet/` directory are automatically picked up without modifying `project.pbxproj`
- **GraphQL** backend (Apollo Server) at `/graphql`
- **Auth**: Supabase JWT — Bearer token in `Authorization` header

## Project Structure

```text
my-wallet/
├── my_walletApp.swift        # @main entry; injects AuthViewModel + ThemeManager, shows RootView
├── ContentView.swift         # Root TabView (Dashboard, Reports, Subscriptions, Net Worth, Profile)
├── Core/
│   ├── Config.swift          # Supabase URL (delegates to Secrets.supabaseAnonKey), GraphQL endpoint
│   ├── Secrets.swift         # Gitignored — holds supabaseAnonKey; copy from Secrets.swift.example
│   ├── Auth/
│   │   └── BiometricAuthService.swift  # LAContext wrapper; canUseBiometrics + authenticate()
│   ├── Supabase/
│   │   └── SupabaseManager.swift       # Shared SupabaseClient instance
│   ├── Network/
│   │   └── GraphQLClient.swift         # URLSession-based GraphQL client
│   ├── Models/
│   │   ├── Report.swift                # Report, Transaction, TransactionType
│   │   ├── Subscription.swift          # Subscription, BillingCycle
│   │   └── NetWorthSnapshot.swift      # NetWorthSnapshot, NetWorthEntry, NetWorthEntryType
│   ├── Extensions/
│   │   └── Array+Safe.swift            # subscript(safe:) helper
│   ├── Components/
│   │   └── CardContainer.swift         # Reusable card wrapper (cornerRadius: 4)
│   └── Theme/
│       ├── AppColors.swift             # Semantic colour tokens (brand, surface, border, income, expense…)
│       ├── CategoryColors.swift        # Per-category colour mapping
│       └── ThemeManager.swift          # @Observable theme state; injected at root
├── Features/
│   ├── Auth/
│   │   ├── AuthViewModel.swift         # Session state; biometric lock; initialize() restores Keychain session
│   │   ├── LoginView.swift
│   │   └── BiometricLockView.swift     # Lock screen shown when isBiometricLocked; auto-prompts Face ID
│   ├── Dashboard/
│   │   ├── DashboardViewModel.swift
│   │   └── DashboardView.swift
│   ├── Reports/
│   │   ├── ReportsViewModel.swift
│   │   ├── ReportsView.swift
│   │   ├── ReportDetailViewModel.swift
│   │   ├── ReportDetailView.swift      # Transactions list with category filter pills
│   │   └── ReportChartsView.swift      # Charts embedded in report detail
│   ├── Subscriptions/
│   │   ├── SubscriptionsViewModel.swift
│   │   └── SubscriptionsView.swift
│   ├── NetWorth/
│   │   ├── NetWorthViewModel.swift
│   │   ├── NetWorthView.swift
│   │   └── NetWorthDetailView.swift
│   └── Profile/
│       ├── ProfileViewModel.swift
│       └── ProfileView.swift
└── Assets.xcassets/
```

## Architecture

- **Feature-based folder structure** — each feature is self-contained
- **MVVM** — Views are dumb; ViewModels hold state and business logic (`@Observable` class or `@StateObject`)
- **NavigationStack** per tab for independent navigation stacks
- **TabView** at root for bottom navigation

## Screens (mirroring web)

| Tab | Web route | Description |
|-----|-----------|-------------|
| Dashboard | `/` | Overview: report summary, charts, subscriptions summary, net worth |
| Reports | `/reports` | List, create, edit, lock reports + transactions |
| Subscriptions | `/subscriptions` | Manage recurring payments |
| Net Worth | `/net-worth` | Snapshots of assets and liabilities |
| Profile | `/profile` | User info and settings |

## Server API

- **Endpoint**: GraphQL at `/graphql`
- **Auth**: `Authorization: Bearer <supabase_jwt>`
- **Key queries/mutations**: reports, transactions, subscriptions, netWorthSnapshots, me

### Core Data Models

```text
User          id, supabaseId, email, fullName
Report        id, title, userId, isLocked, transactions[]
Transaction   id, reportId, type(INCOME|EXPENSE), amount, description, category, date
Subscription  id, userId, name, amount, billingCycle(MONTHLY|YEARLY), isActive, startDate
NetWorthSnapshot  id, userId, title, entries[]
NetWorthEntry     id, snapshotId, type(ASSET|LIABILITY), label, amount, category
```

## Secrets

Credentials are kept out of version control via `Core/Secrets.swift` (gitignored).

```swift
// Core/Secrets.swift
enum Secrets {
    static let supabaseAnonKey = "<your key>"
}
```

Copy `Core/Secrets.swift.example` → `Core/Secrets.swift` and fill in the key. `Config.swift` delegates to `Secrets.supabaseAnonKey`. A missing `Secrets.swift` is a compile error, not a runtime crash.

## Dependencies

- **supabase-swift** — `https://github.com/supabase/supabase-swift` (add via Xcode → File → Add Package Dependencies)
  - Product: `Supabase`
  - Handles Keychain session persistence and token refresh automatically

## Git

- **Never commit without explicit instruction.** Stage and show what changed, but do not run `git commit` unless the user asks.

## Conventions

- Use `@Observable` (Swift 5.9+ macro) for ViewModels, not `ObservableObject`
- Prefer `async/await` over Combine for networking
- SF Symbols for all icons
- No third-party dependencies unless clearly needed — evaluate SwiftUI-native options first
- `AuthViewModel` and `ThemeManager` are injected at the root and accessed via `@Environment`
- Pass `auth.token` into ViewModels rather than making ViewModels auth-aware
- Use `AppColors` tokens for all colours — never hardcode colour literals
- Border radius is **4pt** across all interactive elements (inputs, buttons, cards)
