import Foundation

/// Mirrors the web app's net worth sort options (`NET_WORTH_SORT_OPTIONS`).
enum NetWorthSortOption: String, CaseIterable, Identifiable {
    case date          = "DATE"
    case changeHighLow = "CHANGE_HIGH_LOW"
    case changeLowHigh = "CHANGE_LOW_HIGH"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .date:          return "Created At"
        case .changeHighLow: return "Change (High–Low)"
        case .changeLowHigh: return "Change (Low–High)"
        }
    }
}

struct NetWorthEntryRef: Decodable {
    let type: String
    let label: String
    let amount: Double
    let category: String
    let notes: String?
}

struct PreviousNetWorthSnapshot: Decodable {
    let totalAssets: Double?
    let totalLiabilities: Double?
    let netWorth: Double?
    let entries: [NetWorthEntryRef]?
}

struct NetWorthEntry: Decodable, Identifiable {
    let id: String
    let type: String
    let label: String
    let amount: Double
    let category: String
    let notes: String?
}

struct NetWorthSnapshot: Decodable, Identifiable {
    let id: String
    let title: String
    let snapshotDate: String
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    let createdAt: String
    let updatedAt: String?
    let entries: [NetWorthEntry]?
    let previousSnapshot: PreviousNetWorthSnapshot?

    /// Change in net worth relative to the previous snapshot, or `nil` when
    /// there is no prior snapshot to compare against.
    var delta: Double? {
        guard let prev = previousSnapshot?.netWorth else { return nil }
        return netWorth - prev
    }

    var formattedDate: String {
        parsedSnapshotDate.formatted(date: .abbreviated, time: .omitted)
    }

    var parsedSnapshotDate: Date {
        if let ms = Double(snapshotDate) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: snapshotDate) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: snapshotDate) { return date }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "UTC")
        return df.date(from: snapshotDate) ?? Date()
    }
}
