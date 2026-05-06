import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension Color {
    init(lightHex: UInt32, darkHex: UInt32) {
        #if canImport(UIKit)
        self.init(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: darkHex))
                : UIColor(Color(hex: lightHex))
        })
        #else
        self.init(hex: lightHex)
        #endif
    }

    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double(hex         & 0xFF) / 255
        )
    }
}

enum AppColors {
    static let brand         = Color(lightHex: 0x4F46E5, darkHex: 0x818CF8)
    static let bgApp         = Color(lightHex: 0xF9FAFB, darkHex: 0x111827)
    static let surface       = Color(lightHex: 0xFFFFFF, darkHex: 0x1F2937)
    static let surfaceMuted  = Color(lightHex: 0xF3F4F6, darkHex: 0x374151)
    static let textPrimary   = Color(lightHex: 0x111827, darkHex: 0xF3F4F6)
    static let textSecondary = Color(lightHex: 0x4B5563, darkHex: 0x9CA3AF)
    static let textTertiary  = Color(lightHex: 0x6B7280, darkHex: 0x6B7280)
    static let border        = Color(lightHex: 0xE5E7EB, darkHex: 0x374151)
    static let borderStrong  = Color(lightHex: 0xD1D5DB, darkHex: 0x4B5563)
    static let income        = Color(lightHex: 0x10B981, darkHex: 0x34D399)
    static let expense       = Color(lightHex: 0xEF4444, darkHex: 0xF87171)
    static let warning       = Color(lightHex: 0xF59E0B, darkHex: 0xFBBF24)
}
