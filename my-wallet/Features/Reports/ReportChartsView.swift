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
    @State private var liveValue: Double?
    @State private var committedValue: Double?

    private var total: Double { slices.reduce(0) { $0 + $1.amount } }

    private var selectedSlice: ChartSlice? {
        guard let val = committedValue else { return nil }
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
                        if !isExpanded { committedValue = nil }
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
                                innerRadius: .ratio(0.62),
                                outerRadius: selectedSlice?.label == slice.label ? .ratio(0.95) : .ratio(0.88),
                                angularInset: 1.5
                            )
                            .foregroundStyle(slice.color)
                        }
                        .chartAngleSelection(value: $liveValue)
                        .onChange(of: liveValue) { _, newVal in
                            if let newVal { committedValue = newVal }
                        }
                        .frame(height: 220)

                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                committedValue = nil
                            }
                        } label: {
                            if let sel = selectedSlice {
                                let pct = total > 0 ? sel.amount / total * 100 : 0
                                VStack(spacing: 3) {
                                    Text(sel.label)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(sel.color)
                                    Text(sel.amount.formatted(.currency(code: "EUR")))
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(.primary)
                                    Text(String(format: "%.1f%%", pct))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                            } else {
                                VStack(spacing: 3) {
                                    Text("Total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(total.formatted(.currency(code: "EUR")))
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(.primary)
                                }
                                .transition(.opacity.animation(.easeInOut(duration: 0.15)))
                            }
                        }
                        .buttonStyle(.plain)
                    }

                    let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
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

    private static let colors: [String: Color] = CategoryColors.expense

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
            CategoryColors.budgetBucket["Needs"] ?? CategoryColors.fallback,
            ["Groceries", "Rent", "Transport", "Utilities", "Health", "Insurance", "Loan"]
        ),
        (
            "Wants",
            CategoryColors.budgetBucket["Wants"] ?? CategoryColors.fallback,
            ["Dining Out", "Entertainment", "Shopping", "Other"]
        ),
        (
            "Invest",
            CategoryColors.budgetBucket["Invest"] ?? CategoryColors.fallback,
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
