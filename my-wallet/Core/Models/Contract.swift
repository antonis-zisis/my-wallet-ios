import Foundation

enum ContractSortField: String, CaseIterable, Identifiable {
    case provider = "PROVIDER"
    case endDate  = "END_DATE"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .provider: return "Provider (A–Z)"
        case .endDate:  return "Expiry Date"
        }
    }
}

enum ContractCategory: String, CaseIterable, Identifiable {
    case electricity  = "Electricity"
    case gas          = "Gas"
    case water        = "Water"
    case internet     = "Internet"
    case mobile       = "Mobile"
    case tv           = "TV"
    case insurance    = "Insurance"
    case loanMortgage = "Loan/Mortgage"
    case other        = "Other"

    var id: String { rawValue }
    var label: String { rawValue }
}

let EXPIRING_SOON_DAYS = 30

struct Contract: Decodable, Identifiable {
    let id: String
    let category: String
    let provider: String
    let plan: String?
    let startDate: String?
    let endDate: String?
    let cost: Double?
    let isExpired: Bool

    var daysUntilExpiration: Int? {
        guard let endDate else { return nil }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: Self.parseDate(endDate))
        ).day
    }

    var isExpiringSoon: Bool {
        guard let days = daysUntilExpiration else { return false }
        return days >= 0 && days <= EXPIRING_SOON_DAYS
    }

    var formattedEndDate: String? {
        guard let endDate else { return nil }
        return Self.parseDate(endDate).appFormatted
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
