import Foundation

// MARK: - Sorting

/// Mirrors the web app's report sort options (`REPORT_SORT_OPTIONS` / `REPORT_SORT_CONFIG`).
enum ReportSortOption: String, CaseIterable, Identifiable {
    case newest     = "NEWEST"
    case netHighLow = "NET_HIGH_LOW"
    case netLowHigh = "NET_LOW_HIGH"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest:     return "Created At"
        case .netHighLow: return "Net (High–Low)"
        case .netLowHigh: return "Net (Low–High)"
        }
    }

    /// GraphQL `ReportSortField` value.
    var sortBy: String {
        switch self {
        case .newest:                  return "NEWEST"
        case .netHighLow, .netLowHigh: return "NET_BALANCE"
        }
    }

    /// GraphQL `SortOrder` value.
    var sortOrder: String {
        switch self {
        case .newest, .netHighLow: return "DESC"
        case .netLowHigh:          return "ASC"
        }
    }
}

// MARK: - Date parsing

private func parseServerDate(_ raw: String) -> Date {
    if let ms = Double(raw) {
        return Date(timeIntervalSince1970: ms / 1000)
    }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: raw) { return date }
    iso.formatOptions = [.withInternetDateTime]
    return iso.date(from: raw) ?? Date()
}

// MARK: - Report

struct Report: Decodable, Identifiable {
    let id: String
    var title: String
    var isLocked: Bool
    var transactionCount: Int?
    var netBalance: Double?
    let createdAt: String
    var updatedAt: String
    var transactions: [Transaction]?

    var totalIncome: Double {
        (transactions ?? [])
            .filter { $0.type == .income }
            .reduce(0) { $0 + $1.amount }
    }

    var totalExpenses: Double {
        (transactions ?? [])
            .filter { $0.type == .expense }
            .reduce(0) { $0 + $1.amount }
    }

    var smartUpdatedAt: String {
        let date = parseServerDate(updatedAt)
        let now = Date()
        let days = Calendar.current.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 30 {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: date, relativeTo: now)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().year())
    }

    var relativeUpdatedAt: String { smartUpdatedAt }

    var formattedCreatedAt: String {
        parseServerDate(createdAt).formatted(date: .abbreviated, time: .omitted)
    }

    var formattedUpdatedAt: String {
        parseServerDate(updatedAt).formatted(date: .abbreviated, time: .omitted)
    }
}

extension Report: Hashable {
    static func == (lhs: Report, rhs: Report) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - Transaction

struct Transaction: Decodable, Identifiable {
    let id: String
    let reportId: String
    let type: TransactionType
    let amount: Double
    let description: String
    let category: String
    let date: String
    let createdAt: String
    let updatedAt: String

    var formattedDate: String {
        parseServerDate(date).formatted(date: .abbreviated, time: .omitted)
    }

    var dateAsDate: Date {
        parseServerDate(date)
    }
}

// MARK: - TransactionType

enum TransactionType: String, Decodable {
    case income = "INCOME"
    case expense = "EXPENSE"
}
