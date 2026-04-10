import SwiftUI

struct ReportDetailView: View {
    let stub: Report

    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = ReportDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                metadataCard

                if viewModel.isLoading {
                    loadingContent
                } else if let report = viewModel.report {
                    SummaryCards(report: report)
                    TransactionSection(transactions: report.transactions ?? [])
                } else if viewModel.error != nil {
                    ContentUnavailableView(
                        "Failed to load",
                        systemImage: "exclamationmark.triangle",
                        description: Text("Could not load report details.")
                    )
                    .padding(.top, 32)
                }
            }
            .padding()
        }
        .navigationTitle(stub.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if stub.isLocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("Locked", systemImage: "lock.fill")
                        .labelStyle(.iconOnly)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .task {
            guard let token = auth.token else { return }
            await viewModel.loadReport(id: stub.id, token: token)
        }
    }

    // MARK: - Metadata Card

    private var metadataCard: some View {
        CardContainer {
            VStack(spacing: 8) {
                HStack {
                    Text("Created")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stub.formattedCreatedAt)
                        .font(.caption.weight(.medium))
                }
                Divider()
                HStack {
                    Text("Updated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(stub.formattedUpdatedAt)
                        .font(.caption.weight(.medium))
                }
            }
        }
    }

    // MARK: - Loading Skeleton

    private var loadingContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    CardContainer {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Label")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                            Text("€0,000")
                                .font(.subheadline.bold())
                                .redacted(reason: .placeholder)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            CardContainer {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { i in
                        if i > 0 { Divider() }
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Transaction description")
                                    .font(.subheadline)
                                    .redacted(reason: .placeholder)
                                Text("Category · Jan 1, 2024")
                                    .font(.caption)
                                    .redacted(reason: .placeholder)
                            }
                            Spacer()
                            Text("+€000.00")
                                .font(.subheadline)
                                .redacted(reason: .placeholder)
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Summary Cards

private struct SummaryCards: View {
    let report: Report

    private var netBalance: Double { report.totalIncome - report.totalExpenses }
    private var netColor: Color { netBalance >= 0 ? .green : .red }

    var body: some View {
        HStack(spacing: 12) {
            SummaryStatCard(
                label: "Income",
                value: report.totalIncome.formatted(.currency(code: "EUR")),
                color: .green
            )
            SummaryStatCard(
                label: "Expenses",
                value: report.totalExpenses.formatted(.currency(code: "EUR")),
                color: .red
            )
            SummaryStatCard(
                label: "Net",
                value: netBalance.formatted(.currency(code: "EUR")),
                color: netColor
            )
        }
    }
}

private struct SummaryStatCard: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Transaction Section

private struct TransactionSection: View {
    let transactions: [Transaction]

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Transactions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !transactions.isEmpty {
                    Text("\(transactions.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if transactions.isEmpty {
                CardContainer {
                    Text("No transactions yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                }
            } else {
                CardContainer {
                    VStack(spacing: 0) {
                        ForEach(Array(transactions.enumerated()), id: \.element.id) { index, transaction in
                            if index > 0 { Divider() }
                            TransactionRow(transaction: transaction)
                        }
                    }
                }
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction

    private var amountColor: Color { transaction.type == .income ? .green : .red }
    private var amountSign: String { transaction.type == .income ? "+" : "-" }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(transaction.description)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(transaction.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(transaction.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(amountSign)\(transaction.amount.formatted(.currency(code: "EUR")))")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(amountColor)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ReportDetailView(stub: Report(
            id: "preview",
            title: "January 2024",
            isLocked: false,
            createdAt: "1704067200000",
            updatedAt: "1706745600000",
            transactions: nil
        ))
    }
    .environment(AuthViewModel())
}
