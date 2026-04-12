# my-wallet

An iOS application to help with budgeting. Built with Swift and SwiftUI, targeting iOS App Store.

## Requirements

- Xcode 16+
- iOS 17+
- Swift 6+

## Getting Started

Clone the repository:

```bash
git clone git@github.com:antonis-zisis/my-wallet-ios.git
cd my-wallet-ios
```

Open the project in Xcode:

```bash
open my-wallet.xcodeproj
```

Configure git hooks (enforces conventional commits):

```bash
git config core.hooksPath .githooks
```

Select a simulator or connected device and hit **Cmd+R** to build and run.

## Project Structure

```text
my-wallet-ios/
├── my-wallet/
│   ├── my_walletApp.swift        # App entry point and RootView
│   ├── ContentView.swift         # Root TabView (Dashboard, Reports, Subscriptions, Profile)
│   ├── Core/
│   │   ├── Auth/                 # BiometricAuthService (LocalAuthentication)
│   │   ├── Config.swift          # Supabase URL/key, GraphQL endpoint
│   │   ├── Network/              # URLSession-based GraphQL client
│   │   ├── Models/               # Shared data models
│   │   ├── Extensions/
│   │   ├── Components/           # Reusable SwiftUI components
│   │   ├── Supabase/             # Shared SupabaseClient instance
│   │   └── Theme/                # ThemeManager
│   ├── Features/
│   │   ├── Auth/                 # LoginView, BiometricLockView, AuthViewModel
│   │   ├── Dashboard/
│   │   ├── Reports/
│   │   ├── Subscriptions/
│   │   ├── NetWorth/
│   │   └── Profile/
│   └── Assets.xcassets/
└── my-wallet.xcodeproj/          # Xcode project configuration
```

## Tech Stack

- **Language**: Swift 6
- **UI Framework**: SwiftUI (iOS 17+, targets iOS 26.2)
- **Backend**: GraphQL (Apollo Server) with Supabase JWT auth
- **Biometrics**: Face ID / Touch ID via LocalAuthentication

## License

[Elastic License 2.0](LICENSE)
