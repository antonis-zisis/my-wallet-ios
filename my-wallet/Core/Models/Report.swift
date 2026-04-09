import Foundation

struct Report: Decodable, Identifiable {
    let id: String
    let title: String
    let isLocked: Bool
    let createdAt: String
    let updatedAt: String
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
}

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
}

enum TransactionType: String, Decodable {
    case income = "INCOME"
    case expense = "EXPENSE"
}
