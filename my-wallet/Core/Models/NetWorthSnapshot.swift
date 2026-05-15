import Foundation

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
    let entries: [NetWorthEntry]?

    var formattedDate: String {
        parsedSnapshotDate.formatted(date: .abbreviated, time: .omitted)
    }

    var parsedSnapshotDate: Date {
        if let ms = Double(snapshotDate) {
            return Date(timeIntervalSince1970: ms / 1000)
        }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return iso.date(from: snapshotDate) ?? Date()
    }
}
