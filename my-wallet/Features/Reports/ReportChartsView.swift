import Charts
import SwiftUI

// MARK: - Shared slice model (file-private)

private struct ChartSlice: Identifiable {
    let id = UUID()
    let label: String
    let amount: Double
    let color: Color
}

// MARK: - Reusable donut card (file-private)

private struct DonutChartCard: View {
    let title: String
    let slices: [ChartSlice]

    @State private var isExpanded = false
    @State private var selectedValue: Double?

    private var total: Double { slices.reduce(0) { $0 + $1.amount } }

    private var selectedSlice: ChartSlice? {
        guard let val = selectedValue else { return nil }
        var cumulative = 0.0
        for slice in slices {
            cumulative += slice.amount
            if val <= cumulative { return slice }
        }
        return slices.last
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isExpanded.toggle()
                        if !isExpanded { selectedValue = nil }
                    }
                } label: {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    ZStack {
                        Chart(slices) { slice in
                            SectorMark(
                                angle: .value("Amount", slice.amount),
                                innerRadius: .ratio(0.5),
                                outerRadius: selectedSlice?.label == slice.label ? .ratio(0.95) : .ratio(0.88),
                                angularInset: 1.5
                            )
                            .foregroundStyle(slice.color)
                        }
                        .chartAngleSelection(value: $selectedValue)
                        .frame(height: 220)

                        if let sel = selectedSlice {
                            let pct = total > 0 ? sel.amount / total * 100 : 0
                            VStack(spacing: 2) {
                                Text(sel.label)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(sel.color)
                                Text(sel.amount.formatted(.currency(code: "EUR")))
                                    .font(.caption2.weight(.semibold).monospacedDigit())
                                Text(String(format: "%.1f%%", pct))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .multilineTextAlignment(.center)
                        }
                    }

                    let columns = [GridItem(.flexible()), GridItem(.flexible())]
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                        ForEach(slices) { slice in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(slice.color)
                                    .frame(width: 10, height: 10)
                                Text(slice.label)
                                    .font(.caption)
                                    .foregroundStyle(slice.color)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Expense Breakdown Chart

struct ExpenseBreakdownChart: View {
    let transactions: [Transaction]

    private static let order = [
        "Rent", "Utilities", "Insurance", "Loan", "Groceries",
        "Dining Out", "Transport", "Health", "Entertainment",
        "Shopping", "Investment", "Other",
    ]

    private static let colors: [String: Color] = [
        "Rent":          Color(red: 0.114, green: 0.306, blue: 0.847),
        "Utilities":     Color(red: 0.231, green: 0.510, blue: 0.965),
        "Insurance":     Color(red: 0.376, green: 0.647, blue: 0.980),
        "Loan":          Color(red: 0.118, green: 0.227, blue: 0.541),
        "Groceries":     Color(red: 0.976, green: 0.451, blue: 0.086),
        "Dining Out":    Color(red: 0.984, green: 0.573, blue: 0.235),
        "Transport":     Color(red: 0.035, green: 0.569, blue: 0.698),
        "Health":        Color(red: 0.082, green: 0.722, blue: 0.651),
        "Entertainment": Color(red: 0.659, green: 0.333, blue: 0.969),
        "Shopping":      Color(red: 0.925, green: 0.286, blue: 0.600),
        "Investment":    Color(red: 0.063, green: 0.725, blue: 0.506),
        "Other":         Color(red: 0.612, green: 0.639, blue: 0.686),
    ]

    private var slices: [ChartSlice] {
        var totals: [String: Double] = [:]
        for t in transactions where t.type == .expense {
            totals[t.category, default: 0] += t.amount
        }
        return Self.order.compactMap { cat in
            guard let amount = totals[cat], amount > 0 else { return nil }
            return ChartSlice(label: cat, amount: amount, color: Self.colors[cat] ?? .gray)
        }
    }

    var body: some View {
        if !slices.isEmpty {
            DonutChartCard(title: "Expense Breakdown", slices: slices)
        }
    }
}

// MARK: - Budget Breakdown Chart

struct BudgetBreakdownChart: View {
    let transactions: [Transaction]

    private static let buckets: [(label: String, color: Color, categories: Set<String>)] = [
        (
            "Needs",
            Color(red: 0.231, green: 0.510, blue: 0.965),
            ["Groceries", "Dining Out", "Rent", "Transport", "Utilities", "Health", "Insurance", "Loan"]
        ),
        (
            "Wants",
            Color(red: 0.961, green: 0.620, blue: 0.043),
            ["Entertainment", "Shopping", "Other"]
        ),
        (
            "Invest",
            Color(red: 0.063, green: 0.725, blue: 0.506),
            ["Investment"]
        ),
    ]

    private var slices: [ChartSlice] {
        Self.buckets.compactMap { bucket in
            let total = transactions
                .filter { $0.type == .expense && bucket.categories.contains($0.category) }
                .reduce(0) { $0 + $1.amount }
            guard total > 0 else { return nil }
            return ChartSlice(label: bucket.label, amount: total, color: bucket.color)
        }
    }

    var body: some View {
        if !slices.isEmpty {
            DonutChartCard(title: "Budget Breakdown", slices: slices)
        }
    }
}
