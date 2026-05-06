import SwiftUI

// Canonical cross-platform category palettes — mirrors categoryColors.ts
enum CategoryColors {
    static let fallback = Color(hex: 0x9CA3AF as UInt32)

    // Expense categories — EXPENSE_CATEGORY_COLORS
    static let expense: [String: Color] = expenseMap

    // Budget buckets — BUDGET_BUCKET_COLORS
    static let budgetBucket: [String: Color] = [
        "Invest": Color(hex: 0x10B981 as UInt32),
        "Needs":  Color(hex: 0x3B82F6 as UInt32),
        "Wants":  Color(hex: 0xF59E0B as UInt32),
    ]

    // Asset categories — ASSET_CATEGORY_COLORS
    static let asset: [String: Color] = assetMap

    // Liability categories — LIABILITY_CATEGORY_COLORS
    static let liability: [String: Color] = liabilityMap
}

private let expenseMap: [String: Color] = {
    var m: [String: Color] = [:]
    m["Dining Out"]    = Color(hex: 0xFB923C as UInt32)
    m["Entertainment"] = Color(hex: 0xA855F7 as UInt32)
    m["Groceries"]     = Color(hex: 0xF97316 as UInt32)
    m["Health"]        = Color(hex: 0x14B8A6 as UInt32)
    m["Insurance"]     = Color(hex: 0x60A5FA as UInt32)
    m["Investment"]    = Color(hex: 0x10B981 as UInt32)
    m["Loan"]          = Color(hex: 0x1E3A8A as UInt32)
    m["Other"]         = Color(hex: 0x9CA3AF as UInt32)
    m["Rent"]          = Color(hex: 0x1D4ED8 as UInt32)
    m["Shopping"]      = Color(hex: 0xEC4899 as UInt32)
    m["Transport"]     = Color(hex: 0x0891B2 as UInt32)
    m["Utilities"]     = Color(hex: 0x3B82F6 as UInt32)
    return m
}()

private let assetMap: [String: Color] = {
    var m: [String: Color] = [:]
    m["Brokerage"]   = Color(hex: 0x06B6D4 as UInt32)
    m["Crypto"]      = Color(hex: 0xF59E0B as UInt32)
    m["Investments"] = Color(hex: 0x10B981 as UInt32)
    m["Other"]       = Color(hex: 0x9CA3AF as UInt32)
    m["Real Estate"] = Color(hex: 0xEF4444 as UInt32)
    m["Retirement"]  = Color(hex: 0x8B5CF6 as UInt32)
    m["Savings"]     = Color(hex: 0x3B82F6 as UInt32)
    m["Vehicle"]     = Color(hex: 0x6366F1 as UInt32)
    return m
}()

private let liabilityMap: [String: Color] = {
    var m: [String: Color] = [:]
    m["Car Loan"]      = Color(hex: 0xF97316 as UInt32)
    m["Credit Card"]   = Color(hex: 0xEC4899 as UInt32)
    m["Mortgage"]      = Color(hex: 0xDC2626 as UInt32)
    m["Other"]         = Color(hex: 0x9CA3AF as UInt32)
    m["Personal Loan"] = Color(hex: 0x8B5CF6 as UInt32)
    m["Student Loan"]  = Color(hex: 0xF59E0B as UInt32)
    return m
}()
