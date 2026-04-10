import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
}

@Observable
final class ThemeManager {
    private static let key = "app.theme"

    var current: AppTheme {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: Self.key) }
    }

    var colorScheme: ColorScheme? { current.colorScheme }

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.key) ?? ""
        current = AppTheme(rawValue: stored) ?? .system
    }
}
