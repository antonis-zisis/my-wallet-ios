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
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    let createdAt: String
    let entries: [NetWorthEntry]?

    var formattedDate: String {
        let date: Date
        if let ms = Double(createdAt) {
            date = Date(timeIntervalSince1970: ms / 1000)
        } else {
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            date = iso.date(from: createdAt) ?? Date()
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}
