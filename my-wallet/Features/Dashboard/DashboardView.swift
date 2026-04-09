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
            TotalReportsCard(
                count: viewModel.totalReportsCount,
                isLoading: viewModel.isLoading
            )

            HStack(alignment: .top, spacing: 12) {
                ReportCard(
                    badge: "Current",
                    report: viewModel.currentReport,
                    isLoading: viewModel.isLoading
                )
                ReportCard(
                    badge: "Previous",
                    report: viewModel.previousReport,
                    isLoading: viewModel.isLoading
                )
            }
        }
    }
}

// MARK: - Total Reports Card

private struct TotalReportsCard: View {
    let count: Int?
    let isLoading: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 6) {
                Text("Total Reports")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(count.map(String.init) ?? (isLoading ? "––" : "0"))
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .redacted(reason: isLoading ? .placeholder : [])
                    .contentTransition(.numericText())
            }
        }
    }
}

// MARK: - Report Card

private struct ReportCard: View {
    let badge: String
    let report: Report?
    let isLoading: Bool

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 10) {
                BadgeLabel(text: badge)

                if isLoading {
                    loadingPlaceholder
                } else if let report {
                    reportContent(report)
                } else {
                    Text("No report")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Loading report title")
                .font(.headline)
                .redacted(reason: .placeholder)

            AmountRow(icon: "arrow.up", label: "Income", amount: 0, color: .green)
                .redacted(reason: .placeholder)

            AmountRow(icon: "arrow.down", label: "Expenses", amount: 0, color: .red)
                .redacted(reason: .placeholder)
        }
    }

    private func reportContent(_ report: Report) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(report.title)
                .font(.headline)
                .lineLimit(2)

            AmountRow(icon: "arrow.up", label: "Income", amount: report.totalIncome, color: .green)
            AmountRow(icon: "arrow.down", label: "Expenses", amount: report.totalExpenses, color: .red)
        }
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
