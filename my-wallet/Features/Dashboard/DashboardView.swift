import SwiftUI

// MARK: - Main View

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ReportSummarySection(viewModel: viewModel)
                    Divider()
                        .padding(.vertical, 16)
                    SubscriptionsSection(viewModel: viewModel)
                    Divider()
                        .padding(.vertical, 16)
                    NetWorthSection(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .task {
                guard let token = auth.token else { return }
                await viewModel.loadData(token: token)
            }
            .refreshable {
                guard let token = auth.token else { return }
                await viewModel.loadData(token: token)
            }
        }
    }
}

// MARK: - Report Summary Section

private struct ReportSummarySection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Reports", systemImage: "doc.text")

            if viewModel.isLoading {
                reportsLoadingPlaceholder
            } else if (viewModel.totalReportsCount ?? 0) == 0 {
                EmptySectionCard(
                    systemImage: "doc.text",
                    title: "No reports yet",
                    message: "Create your first report to start tracking income and expenses."
                )
            } else {
                TotalReportsCard(count: viewModel.totalReportsCount)
                ReportCard(badge: "Current", report: viewModel.currentReport)
                ReportCard(badge: "Previous", report: viewModel.previousReport)
            }
        }
    }

    private var reportsLoadingPlaceholder: some View {
        VStack(spacing: 12) {
            CardContainer {
                HStack {
                    Text("Total")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("––")
                        .font(.title2.bold().monospacedDigit())
                        .redacted(reason: .placeholder)
                }
            }
            ForEach(["Current", "Previous"], id: \.self) { badge in
                CardContainer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Loading report title")
                                .font(.headline)
                                .redacted(reason: .placeholder)
                            Spacer()
                            BadgeLabel(text: badge)
                                .redacted(reason: .placeholder)
                        }
                        AmountRow(icon: "arrow.up", label: "Income", amount: 0, color: .green)
                            .redacted(reason: .placeholder)
                        AmountRow(icon: "arrow.down", label: "Expenses", amount: 0, color: .red)
                            .redacted(reason: .placeholder)
                    }
                }
            }
        }
    }
}

// MARK: - Total Reports Card

private struct TotalReportsCard: View {
    let count: Int?

    var body: some View {
        CardContainer {
            HStack {
                Text("Total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(count.map(String.init) ?? "0")
                    .font(.title2.bold().monospacedDigit())
                    .contentTransition(.numericText())
            }
        }
    }
}

// MARK: - Report Card

private struct ReportCard: View {
    let badge: String
    let report: Report?

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                if let report {
                    reportContent(report)
                } else {
                    HStack {
                        Text("No report")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                        BadgeLabel(text: badge)
                    }
                }
            }
        }
    }

    private func reportContent(_ report: Report) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(report.title)
                    .font(.headline)
                    .lineLimit(2)
                Spacer()
                BadgeLabel(text: badge)
            }
            AmountRow(icon: "arrow.up", label: "Income", amount: report.totalIncome, color: .green)
            AmountRow(icon: "arrow.down", label: "Expenses", amount: report.totalExpenses, color: .red)
        }
    }
}

// MARK: - Subscriptions Section

private struct SubscriptionsSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Subscriptions", systemImage: "repeat.circle")

            if viewModel.isLoading {
                subscriptionsLoadingPlaceholder
            } else if viewModel.subscriptions.isEmpty {
                EmptySectionCard(
                    systemImage: "repeat.circle",
                    title: "No subscriptions yet",
                    message: "Track your recurring payments in the Subscriptions tab."
                )
            } else {
                SubscriptionSummaryCards(
                    subscriptions: viewModel.subscriptions,
                    currentIncome: viewModel.currentReport?.totalIncome ?? 0
                )
                UpcomingRenewalsCard(subscriptions: viewModel.subscriptions)
            }
        }
    }

    private var subscriptionsLoadingPlaceholder: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    CardContainer {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Loading label")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                            Text("0")
                                .font(.title2.bold())
                                .redacted(reason: .placeholder)
                        }
                    }
                }
            }
            CardContainer {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Upcoming Renewals")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Subscription name")
                                    .font(.subheadline)
                                    .redacted(reason: .placeholder)
                                Text("Date")
                                    .font(.caption)
                                    .redacted(reason: .placeholder)
                            }
                            Spacer()
                            Text("€00.00")
                                .font(.subheadline)
                                .redacted(reason: .placeholder)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Net Worth Section

private struct NetWorthSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Net Worth", systemImage: "chart.line.uptrend.xyaxis")

            if viewModel.isLoading {
                netWorthLoadingPlaceholder
            } else if let snapshot = viewModel.latestSnapshot {
                NetWorthCard(snapshot: snapshot)
            } else {
                EmptySectionCard(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No snapshot yet",
                    message: "Track your assets and liabilities to see your net worth."
                )
            }
        }
    }

    private var netWorthLoadingPlaceholder: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Net Worth")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                    Spacer()
                    Text("€00,000")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                }
                HStack(spacing: 12) {
                    ForEach(["Assets", "Liabilities", "Net Worth"], id: \.self) { label in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(label)
                                .font(.caption)
                                .redacted(reason: .placeholder)
                            Text("€0")
                                .font(.title3.bold())
                                .redacted(reason: .placeholder)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }
}

// MARK: - Net Worth Card

private struct NetWorthCard: View {
    let snapshot: NetWorthSnapshot
    @State private var isExpanded = false

    private var netWorthColor: Color { snapshot.netWorth >= 0 ? .green : .red }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text("Net Worth")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text(snapshot.netWorth.formatted(.currency(code: "EUR")))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(netWorthColor)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(snapshot.title)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                            Spacer()
                            Text(snapshot.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 12) {
                            NetWorthStatColumn(
                                label: "Assets",
                                amount: snapshot.totalAssets,
                                color: .green
                            )
                            NetWorthStatColumn(
                                label: "Liabilities",
                                amount: snapshot.totalLiabilities,
                                color: .red
                            )
                            NetWorthStatColumn(
                                label: "Net Worth",
                                amount: snapshot.netWorth,
                                color: netWorthColor
                            )
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
    }
}

private struct NetWorthStatColumn: View {
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(amount.formatted(.currency(code: "EUR")))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Empty Section Card

private struct EmptySectionCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        CardContainer {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Subscription Summary Cards

private struct SubscriptionSummaryCards: View {
    let subscriptions: [Subscription]
    let currentIncome: Double

    private var totalMonthlyCost: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    private var percentOfIncome: String {
        guard currentIncome > 0 else { return "-" }
        let pct = (totalMonthlyCost / currentIncome) * 100
        return String(format: "%.1f%%", pct)
    }

    var body: some View {
        HStack(spacing: 12) {
            StatCard(label: "Active", value: "\(subscriptions.count)")
            StatCard(label: "Monthly Cost", value: totalMonthlyCost.formatted(.currency(code: "EUR")))
            StatCard(label: "% of Income", value: percentOfIncome)
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(value)
                    .font(.title3.bold().monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Upcoming Renewals Card

private struct UpcomingRenewalsCard: View {
    let subscriptions: [Subscription]
    @State private var isExpanded = true

    private var sorted: [Subscription] {
        subscriptions
            .sorted { $0.nextRenewalDate < $1.nextRenewalDate }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text("Upcoming Renewals")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, sub in
                            if index > 0 { Divider() }
                            RenewalRow(subscription: sub)
                        }
                    }
                    .padding(.top, 12)
                }
            }
        }
    }
}

private struct RenewalRow: View {
    let subscription: Subscription

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.subheadline.weight(.medium))
                Text(subscription.nextRenewalDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(subscription.amount.formatted(.currency(code: "EUR")))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Supporting Views

private struct BadgeLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.tint.opacity(0.12))
            .foregroundStyle(.tint)
            .clipShape(Capsule())
    }
}

private struct AmountRow: View {
    let icon: String
    let label: String
    let amount: Double
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(amount.formatted(.currency(code: "EUR")))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AuthViewModel())
}
