import SwiftUI

// MARK: - Net Worth Detail View

struct NetWorthDetailView: View {
    let stub: NetWorthSnapshot
    let viewModel: NetWorthViewModel

    @Environment(AuthViewModel.self) private var auth
    @State private var detail: NetWorthSnapshot?
    @State private var isLoading = false
    @State private var error = false

    private var snapshot: NetWorthSnapshot { detail ?? stub }
    private var netWorthColor: Color { snapshot.netWorth >= 0 ? AppColors.income : AppColors.expense }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                headerCard

                if isLoading {
                    loadingPlaceholder
                } else if error {
                    Text("Failed to load snapshot details.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                } else if let entries = detail?.entries {
                    let assets = entries.filter { $0.type == "ASSET" }
                    let liabilities = entries.filter { $0.type == "LIABILITY" }
                    if !assets.isEmpty {
                        EntriesSection(title: "Assets", entries: assets, totalColor: AppColors.income, total: snapshot.totalAssets)
                    }
                    if !liabilities.isEmpty {
                        EntriesSection(title: "Liabilities", entries: liabilities, totalColor: AppColors.expense, total: snapshot.totalLiabilities)
                    }
                }
            }
            .padding()
        }
        .background(AppColors.bgApp)
        .navigationTitle(stub.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard let token = auth.token else { return }
            isLoading = true
            defer { isLoading = false }
            do {
                detail = try await viewModel.loadDetail(id: stub.id, token: token)
            } catch {
                self.error = true
            }
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(snapshot.title)
                        .font(.headline)
                    Spacer()
                    Text(snapshot.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 0) {
                    NetWorthDetailStatColumn(label: "Assets", amount: snapshot.totalAssets, color: AppColors.income)
                    NetWorthDetailStatColumn(label: "Liabilities", amount: snapshot.totalLiabilities, color: AppColors.expense)
                    NetWorthDetailStatColumn(label: "Net Worth", amount: snapshot.netWorth, color: netWorthColor)
                }
            }
        }
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        CardContainer {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Entry label placeholder")
                                .font(.subheadline)
                                .redacted(reason: .placeholder)
                            Text("Category")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                        }
                        Spacer()
                        Text("€0,000.00")
                            .font(.subheadline)
                            .redacted(reason: .placeholder)
                    }
                    .padding(.vertical, 10)
                    if index < 3 { Divider() }
                }
            }
        }
    }
}

// MARK: - Stat Column

private struct NetWorthDetailStatColumn: View {
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

// MARK: - Entries Section

private struct EntriesSection: View {
    let title: String
    let entries: [NetWorthEntry]
    let totalColor: Color
    let total: Double

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Text(total.formatted(.currency(code: "EUR")))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(totalColor)
                        .monospacedDigit()
                }
                .padding(.bottom, 10)

                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    if index > 0 { Divider() }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.label)
                                .font(.subheadline.weight(.medium))
                            Text(entry.category)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(entry.amount.formatted(.currency(code: "EUR")))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(totalColor)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}
