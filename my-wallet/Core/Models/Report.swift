import Foundation

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

    var relativeUpdatedAt: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: parseServerDate(updatedAt), relativeTo: Date())
    }

    var formattedCreatedAt: String {
        parseServerDate(createdAt).formatted(date: .abbreviated, time: .omitted)
    }

    var formattedUpdatedAt: String {
        parseServerDate(updatedAt).formatted(date: .abbreviated, time: .omitted)
    }
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
