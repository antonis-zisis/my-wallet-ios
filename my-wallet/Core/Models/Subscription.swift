import Foundation

enum BillingCycle: String, Codable, CaseIterable {
    case weekly    = "WEEKLY"
    case monthly   = "MONTHLY"
    case quarterly = "QUARTERLY"
    case biAnnual  = "BI_ANNUAL"
    case yearly    = "YEARLY"

    var label: String {
        switch self {
        case .weekly:    return "Weekly"
        case .monthly:   return "Monthly"
        case .quarterly: return "Quarterly"
        case .biAnnual:  return "Bi-annual"
        case .yearly:    return "Yearly"
        }
    }

    var monthIncrement: Int {
        switch self {
        case .weekly:    return 0
        case .monthly:   return 1
        case .quarterly: return 3
        case .biAnnual:  return 6
        case .yearly:    return 12
        }
    }
}

/// Mirrors the web app's subscription sort options (`SUBSCRIPTION_SORT_OPTIONS`).
enum SubscriptionSortOption: String, CaseIterable, Identifiable {
    case name        = "NAME"
    case costHighLow = "COST_HIGH_LOW"
    case costLowHigh = "COST_LOW_HIGH"
    case nextRenewal = "NEXT_RENEWAL"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name:        return "Name (A–Z)"
        case .costHighLow: return "Cost (High–Low)"
        case .costLowHigh: return "Cost (Low–High)"
        case .nextRenewal: return "Next Renewal"
        }
    }
}

enum SubscriptionCategory: String, CaseIterable, Identifiable {
    case entertainment = "Entertainment"
    case productivity  = "Productivity"
    case utilities     = "Utilities"
    case health        = "Health"
    case finance       = "Finance"
    case education     = "Education"
    case music         = "Music"
    case news          = "News"
    case other         = "Other"

    var id: String { rawValue }
    var label: String { rawValue }
}

struct Subscription: Decodable, Identifiable {
    let id: String
    let name: String
    let amount: Double
    let billingCycle: BillingCycle
    let isActive: Bool
    let startDate: String
    let endDate: String?
    let cancelledAt: String?
    let trialEndsAt: String?
    let category: String?
    let notes: String?
    let paymentMethod: String?
    let url: String?
    let monthlyCost: Double

    var isCancelled: Bool { cancelledAt != nil }

    var isInTrial: Bool {
        guard let trialEndsAt else { return false }
        return Date() < Self.parseDate(trialEndsAt)
    }

    var trialDaysRemaining: Int? {
        guard let trialEndsAt, isInTrial else { return nil }
        let end = Self.parseDate(trialEndsAt)
        let calendar = Calendar.current
        return calendar.dateComponents([.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: end)).day
    }

    var nextRenewalDate: Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var next = Self.parseDate(startDate)
        while next <= today {
            switch billingCycle {
            case .weekly:
                next = calendar.date(byAdding: .day, value: 7, to: next) ?? next
            default:
                next = calendar.date(byAdding: .month, value: billingCycle.monthIncrement, to: next) ?? next
            }
        }
        return next
    }

    var formattedNextRenewalDate: String {
        nextRenewalDate.appFormatted
    }

    var daysUntilNextRenewal: Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: nextRenewalDate)
        ).day ?? 0
    }

    var formattedEndDate: String? {
        guard let endDate else { return nil }
        return Self.parseDate(endDate).appFormatted
    }

    var formattedTrialEndDate: String? {
        guard let trialEndsAt else { return nil }
        return Self.parseDate(trialEndsAt).appFormatted
    }

    var detailLine: String? {
        var parts: [String] = []
        if let pm = paymentMethod, !pm.isEmpty { parts.append("via \(pm)") }
        if let n = notes, !n.isEmpty { parts.append(n) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    static func parseDate(_ raw: String) -> Date {
        if let ms = Double(raw) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw) ?? Date()
    }
}
