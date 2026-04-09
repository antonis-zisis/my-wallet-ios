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
├── App/                     # App entry point and root navigation
├── Features/                # One folder per feature/screen
│   ├── Dashboard/
│   ├── Reports/
│   ├── Subscriptions/
│   └── Profile/
├── Core/                    # Shared, non-feature code
│   ├── Network/             # GraphQL client, request/response models
│   ├── Models/              # Shared data models
│   └── Extensions/          # Swift/SwiftUI extensions
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

## Conventions

- Use `@Observable` (Swift 5.9+ macro) for ViewModels, not `ObservableObject`
- Prefer `async/await` over Combine for networking
- SF Symbols for all icons
- No third-party dependencies until clearly needed — evaluate SwiftUI-native options first
