import Charts
import SwiftUI

// MARK: - Main View

struct DashboardView: View {
    @Environment(AuthViewModel.self) private var auth
    @Environment(ThemeManager.self) private var theme
    @State private var viewModel = DashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 36) {
                    ReportSummarySection(viewModel: viewModel)
                    SubscriptionsSection(viewModel: viewModel)
                    ContractsSection(viewModel: viewModel)
                    NetWorthSection(viewModel: viewModel)
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Overview")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        theme.hideAmounts.toggle()
                    } label: {
                        Image(systemName: theme.hideAmounts ? "eye.slash" : "eye")
                    }
                }
            }
            .task {
                guard let token = auth.token else { return }
                await viewModel.loadData(token: token)
            }
            .onChange(of: auth.token) { _, newToken in
                guard let token = newToken,
                      !viewModel.showLoadingState,
                      viewModel.totalReportsCount == nil else { return }
                Task { await viewModel.loadData(token: token) }
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
    @Environment(AppRouter.self) private var router

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Reports", systemImage: "doc.text")

            if viewModel.showLoadingState {
                reportsLoadingPlaceholder
            } else if (viewModel.totalReportsCount ?? 0) == 0 {
                EmptySectionCard(
                    systemImage: "doc.text",
                    title: "No reports yet",
                    message: "Create your first report to start tracking income and expenses."
                )
            } else {
                TotalReportsCard(count: viewModel.totalReportsCount)
                reportCardLink(badge: "Current", report: viewModel.currentReport)
                reportCardLink(badge: "Previous", report: viewModel.previousReport)
                if !viewModel.reportSummaries.isEmpty {
                    IncomeExpensesCard(summaries: viewModel.reportSummaries)
                }
            }
        }
    }

    @ViewBuilder
    private func reportCardLink(badge: String, report: Report?) -> some View {
        if let report {
            Button {
                router.openReport(report)
            } label: {
                ReportCard(badge: badge, report: report)
            }
            .buttonStyle(.plain)
        } else {
            ReportCard(badge: badge, report: report)
        }
    }

    private var reportsLoadingPlaceholder: some View {
        VStack(spacing: 12) {
            CardContainer(verticalPadding: 8) {
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.semibold))
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
                        AmountRow(icon: "arrow.up", label: "Income", amount: 0, color: AppColors.income)
                            .redacted(reason: .placeholder)
                        AmountRow(icon: "arrow.down", label: "Expenses", amount: 0, color: AppColors.expense)
                            .redacted(reason: .placeholder)
                    }
                }
            }
            CardContainer {
                HStack {
                    Text("Monthly Summary")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Total Reports Card

private struct TotalReportsCard: View {
    let count: Int?

    var body: some View {
        CardContainer(verticalPadding: 8) {
            HStack {
                Text("Total")
                    .font(.subheadline.weight(.semibold))
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
            AmountRow(icon: "arrow.up", label: "Income", amount: report.totalIncome, color: AppColors.income)
            AmountRow(icon: "arrow.down", label: "Expenses", amount: report.totalExpenses, color: AppColors.expense)
        }
    }
}

// MARK: - Subscriptions Section

private struct SubscriptionsSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Subscriptions", systemImage: "repeat.circle")

            if viewModel.showLoadingState {
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
            CardContainer(verticalPadding: 8) {
                HStack {
                    Text("Total")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("––")
                        .font(.title2.bold().monospacedDigit())
                        .redacted(reason: .placeholder)
                }
            }
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { _ in
                    CardContainer(expandHeight: true) {
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

// MARK: - Contracts Section

private struct ContractsSection: View {
    let viewModel: DashboardViewModel

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader(title: "Contracts", systemImage: "doc.text")

            if viewModel.showLoadingState {
                contractsLoadingPlaceholder
            } else {
                ContractsExpiringSoonCard(contracts: viewModel.expiringContracts)
            }
        }
    }

    private var contractsLoadingPlaceholder: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Contracts Expiring Soon")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                ForEach(0..<2, id: \.self) { _ in
                    HStack {
                        Text("Provider name")
                            .font(.subheadline)
                            .redacted(reason: .placeholder)
                        Spacer()
                        Text("expires in 12 days")
                            .font(.caption)
                            .redacted(reason: .placeholder)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

private struct ContractsExpiringSoonCard: View {
    let contracts: [Contract]
    @State private var isExpanded = false

    private let visibleLimit = 3

    private var visible: [Contract] { Array(contracts.prefix(visibleLimit)) }
    private var overflow: Int { max(0, contracts.count - visible.count) }

    private func countdown(_ days: Int) -> String {
        switch days {
        case 0:  return "expires today"
        case 1:  return "expires tomorrow"
        default: return "expires in \(days) days"
        }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text("Contracts Expiring Soon")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if contracts.isEmpty {
                        Text("No contracts expiring soon.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(visible.enumerated()), id: \.element.id) { index, contract in
                                if index > 0 { Divider() }
                                HStack(spacing: 8) {
                                    Text(contract.provider)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(contract.category)
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.12))
                                        .foregroundStyle(.secondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    Spacer()
                                    Text(countdown(contract.daysUntilExpiration ?? 0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.top, 12)

                        if overflow > 0 {
                            Text("+\(overflow) more")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tint)
                                .padding(.top, 8)
                        }
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

            if viewModel.showLoadingState {
                netWorthLoadingPlaceholder
            } else if let snapshot = viewModel.latestSnapshot {
                NetWorthCard(
                    snapshot: snapshot,
                    previousSnapshot: viewModel.previousSnapshot,
                    recentSnapshots: viewModel.recentSnapshots
                )
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
            HStack {
                Text("Net Worth")
                    .font(.headline)
                    .redacted(reason: .placeholder)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Net Worth Card

private struct NetWorthCard: View {
    let snapshot: NetWorthSnapshot
    let previousSnapshot: NetWorthSnapshot?
    let recentSnapshots: [NetWorthSnapshot]
    @State private var isExpanded = false
    @Environment(ThemeManager.self) private var theme

    private var netWorthColor: Color { snapshot.netWorth >= 0 ? AppColors.income : AppColors.expense }

    private var delta: Double? {
        guard let prev = previousSnapshot else { return nil }
        return snapshot.netWorth - prev.netWorth
    }

    private var daysAgo: Int {
        let date = snapshot.parsedSnapshotDate
        return max(0, Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0)
    }

    private var isStale: Bool { daysAgo > 45 }

    private var stalenessText: String {
        switch daysAgo {
        case 0: return "Last updated today"
        case 1: return "Last updated yesterday"
        default: return "Last updated \(daysAgo) days ago"
        }
    }

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
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(snapshot.title)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.tint)
                                .lineLimit(1)
                            Spacer()
                            Text(snapshot.formattedDate)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(snapshot.netWorth.maskedCurrency(hidden: theme.hideAmounts))
                                .font(.title.bold())
                                .foregroundStyle(netWorthColor)

                            if let delta {
                                let deltaPositive = delta >= 0
                                HStack(spacing: 4) {
                                    Image(systemName: deltaPositive ? "arrow.up" : "arrow.down")
                                        .font(.caption.weight(.semibold))
                                    Text(
                                        "\(deltaPositive ? "+" : "-")\(abs(delta).maskedCurrency(hidden: theme.hideAmounts)) since \(previousSnapshot!.title)"
                                    )
                                    .font(.caption.weight(.medium))
                                }
                                .foregroundStyle(deltaPositive ? AppColors.income : AppColors.expense)
                            }
                        }

                        if recentSnapshots.count >= 2 {
                            NetWorthSparkline(snapshots: recentSnapshots, isPositive: snapshot.netWorth >= 0)
                        }

                        Text(isStale ? "\(stalenessText) — time for a new snapshot?" : stalenessText)
                            .font(.caption)
                            .foregroundStyle(isStale ? Color.orange : Color.secondary)
                    }
                    .padding(.top, 16)
                }
            }
        }
    }
}

private struct NetWorthSparkline: View {
    let snapshots: [NetWorthSnapshot]
    let isPositive: Bool

    private struct SparkPoint: Identifiable {
        let id: Int
        let netWorth: Double
    }

    private var points: [SparkPoint] {
        snapshots.enumerated().map { SparkPoint(id: $0.offset, netWorth: $0.element.netWorth) }
    }

    var body: some View {
        Chart(points) { point in
            LineMark(
                x: .value("Index", point.id),
                y: .value("Net Worth", point.netWorth)
            )
            .foregroundStyle(isPositive ? AppColors.income : AppColors.expense)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 48)
    }
}

// MARK: - Income & Expenses Card

private struct IncomeExpensesCard: View {
    let summaries: [ReportSummaryItem]

    @Environment(ThemeManager.self) private var theme
    @State private var isExpanded = false

    private struct BarEntry: Identifiable {
        let id = UUID()
        let title: String
        let type: String
        let amount: Double
    }

    private var entries: [BarEntry] {
        summaries.flatMap { report in
            [
                BarEntry(title: report.title, type: "Income", amount: report.totalIncome),
                BarEntry(title: report.title, type: "Expenses", amount: report.totalExpenses),
            ]
        }
    }

    private static let fullMonthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    private static let shortMonthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM ''yy"
        return f
    }()

    private static func shortChartLabel(_ title: String) -> String {
        if let date = fullMonthYearFormatter.date(from: title) {
            return shortMonthYearFormatter.string(from: date)
        }
        return title.count > 8 ? String(title.prefix(7)) + "…" : title
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { isExpanded.toggle() }
                } label: {
                    HStack {
                        Text("Monthly Summary")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Chart(entries) { entry in
                        BarMark(
                            x: .value("Report", entry.title),
                            y: .value("Amount", entry.amount)
                        )
                        .foregroundStyle(by: .value("Type", entry.type))
                        .position(by: .value("Type", entry.type))
                        .cornerRadius(3)
                    }
                    .chartForegroundStyleScale(["Income": AppColors.income, "Expenses": AppColors.expense])
                    .chartLegend(position: .top, alignment: .leading)
                    .chartXAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let t = value.as(String.self) {
                                    Text(Self.shortChartLabel(t))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .chartYAxis {
                        AxisMarks { value in
                            AxisValueLabel {
                                if let amount = value.as(Double.self) {
                                    Text(theme.hideAmounts ? "***" : amount.formatted(.currency(code: "EUR").presentation(.narrow)))
                                        .font(.caption2)
                                }
                            }
                            AxisGridLine()
                        }
                    }
                    .frame(height: 220)
                    .padding(.top, 16)
                }
            }
        }
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

    @Environment(ThemeManager.self) private var theme

    private var totalMonthlyCost: Double {
        subscriptions.reduce(0) { $0 + $1.monthlyCost }
    }

    private var totalYearlyCost: Double { totalMonthlyCost * 12 }

    private var percentOfIncome: String {
        guard currentIncome > 0 else { return "-" }
        let pct = (totalMonthlyCost / currentIncome) * 100
        return String(format: "%.1f%%", pct)
    }

    var body: some View {
        VStack(spacing: 12) {
            TotalReportsCard(count: subscriptions.count)
            HStack(spacing: 12) {
                StatCard(label: "Monthly Cost", value: totalMonthlyCost.maskedCurrency(hidden: theme.hideAmounts))
                StatCard(label: "Yearly Cost", value: totalYearlyCost.maskedCurrency(hidden: theme.hideAmounts))
                StatCard(label: "% of Income", value: percentOfIncome, info: "Based on the income of your latest report.")
            }
        }
    }
}

private struct StatCard: View {
    let label: String
    let value: String
    var info: String? = nil

    @State private var showInfo = false

    var body: some View {
        CardContainer(expandHeight: true) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 3) {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    if let info {
                        Button {
                            showInfo = true
                        } label: {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showInfo) {
                            Text(info)
                                .font(.caption)
                                .padding(12)
                                .presentationCompactAdaptation(.popover)
                        }
                    }
                }
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
    @State private var isExpanded = false
    @State private var showInfo = false

    private var sorted: [Subscription] {
        let today = Calendar.current.startOfDay(for: Date())
        return subscriptions
            .filter { sub in
                let days = Calendar.current.dateComponents(
                    [.day],
                    from: today,
                    to: Calendar.current.startOfDay(for: sub.nextRenewalDate)
                ).day ?? 0
                return days <= 40
            }
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
                        Button { showInfo = true } label: {
                            Image(systemName: "info.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showInfo) {
                            Text("Shows up to 5 active subscriptions renewing within the next 40 days, sorted by nearest date.")
                                .font(.caption)
                                .padding(12)
                                .presentationCompactAdaptation(.popover)
                        }
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if isExpanded {
                    if sorted.isEmpty {
                        Text("No renewals due in the next 40 days.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 12)
                    } else {
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
}

private struct RenewalRow: View {
    let subscription: Subscription

    @Environment(ThemeManager.self) private var theme

    private var daysUntil: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let target = Calendar.current.startOfDay(for: subscription.nextRenewalDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }

    private var urgencyLabel: String {
        switch daysUntil {
        case 0: return "Today"
        case 1: return "Tomorrow"
        default: return "in \(daysUntil)d"
        }
    }

    private var urgencyColor: Color {
        if daysUntil <= 3 { return .red }
        if daysUntil <= 7 { return .orange }
        return .secondary
    }

    private var billingCycleLabel: String {
        subscription.billingCycle == .monthly ? "Monthly" : "Yearly"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(subscription.name)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(billingCycleLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(subscription.nextRenewalDate, format: .dateTime.month(.abbreviated).day().year())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(urgencyLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(urgencyColor)
                }
            }
            Spacer()
            Text(subscription.amount.maskedCurrency(hidden: theme.hideAmounts))
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Supporting Views

private struct BadgeLabel: View {
    let text: String
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(colorScheme == .dark ? Color.accentColor : Color.accentColor.opacity(0.2))
            .foregroundStyle(colorScheme == .dark ? Color.white : Color.accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct AmountRow: View {
    let icon: String
    let label: String
    let amount: Double
    let color: Color

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(amount.maskedCurrency(hidden: theme.hideAmounts))
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
        }
    }
}

// MARK: - Preview

#Preview {
    DashboardView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
        .environment(AppRouter())
}
