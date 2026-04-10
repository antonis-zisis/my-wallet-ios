import Foundation

enum BillingCycle: String, Decodable {
    case monthly = "MONTHLY"
    case yearly = "YEARLY"
}

struct Subscription: Decodable, Identifiable {
    let id: String
    let name: String
    let amount: Double
    let billingCycle: BillingCycle
    let isActive: Bool
    let startDate: String
    let monthlyCost: Double

    /// Returns the next renewal date after today, advancing by billing cycle increments.
    var nextRenewalDate: Date {
        let parsed = Self.parseDate(startDate)
        let today = Calendar.current.startOfDay(for: Date())
        let increment = billingCycle == .monthly ? 1 : 12
        var next = parsed
        while next <= today {
            next = Calendar.current.date(byAdding: .month, value: increment, to: next) ?? next
        }
        return next
    }

    private static func parseDate(_ raw: String) -> Date {
        // Server sends epoch milliseconds as a string, or ISO-8601
        if let ms = Double(raw) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: raw) ?? Date()
    }
}
