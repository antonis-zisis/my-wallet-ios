import Foundation

struct NetWorthEntryRef: Decodable {
    let type: String
    let label: String
    let amount: Double
    let category: String
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
