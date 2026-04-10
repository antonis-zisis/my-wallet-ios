import Foundation

struct NetWorthSnapshot: Decodable, Identifiable {
    let id: String
    let title: String
    let totalAssets: Double
    let totalLiabilities: Double
    let netWorth: Double
    let createdAt: String

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
