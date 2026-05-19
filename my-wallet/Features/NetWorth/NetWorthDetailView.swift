import SwiftUI

// MARK: - Net Worth Detail View

struct NetWorthDetailView: View {
    let stub: NetWorthSnapshot
    let viewModel: NetWorthViewModel

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var detail: NetWorthSnapshot?
    @State private var isLoading = false
    @State private var error = false
    @State private var sheetMode: NetWorthSheetMode?
    @State private var showDeleteConfirm = false

    private var snapshot: NetWorthSnapshot { detail ?? stub }
    private var netWorthColor: Color { snapshot.netWorth >= 0 ? AppColors.income : AppColors.expense }

    // MARK: - Deltas

    private var deltaNetWorth: Double? {
        guard let prev = snapshot.previousSnapshot?.netWorth else { return nil }
        return snapshot.netWorth - prev
    }

    private var deltaAssets: Double? {
        guard let prev = snapshot.previousSnapshot?.totalAssets else { return nil }
        return snapshot.totalAssets - prev
    }

    private var deltaLiabilities: Double? {
        guard let prev = snapshot.previousSnapshot?.totalLiabilities else { return nil }
        return snapshot.totalLiabilities - prev
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                headerCard

                if isLoading {
                    loadingPlaceholder
                } else if error {
                    Text("Failed to load snapshot details.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                } else if let entries = snapshot.entries {
                    let prevEntries = snapshot.previousSnapshot?.entries
                    let assets = entries.filter { $0.type == "ASSET" }
                    let liabilities = entries.filter { $0.type == "LIABILITY" }
                    if !assets.isEmpty {
                        EntriesSection(
                            title: "Assets",
                            entries: assets,
                            totalColor: AppColors.income,
                            total: snapshot.totalAssets,
                            previousEntries: prevEntries
                        )
                    }
                    if !liabilities.isEmpty {
                        EntriesSection(
                            title: "Liabilities",
                            entries: liabilities,
                            totalColor: AppColors.expense,
                            total: snapshot.totalLiabilities,
                            previousEntries: prevEntries
                        )
                    }
                }
            }
            .padding()
        }
        .background(AppColors.bgApp)
        .navigationTitle(stub.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { sheetMode = .edit(snapshot) } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button { sheetMode = .duplicate(snapshot) } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    Divider()
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task { await loadDetail() }
        .sheet(item: $sheetMode) { mode in
            NetWorthSnapshotSheet(
                mode: mode,
                onCreate: { input in
                    guard let token = auth.token else { return }
                    Task { await viewModel.create(input: input, token: token) }
                },
                onUpdate: { id, input in
                    guard let token = auth.token else { return }
                    Task {
                        if let updated = try? await viewModel.update(id: id, input: input, token: token) {
                            detail = updated
                        }
                    }
                }
            )
        }
        .alert(
            "Delete Snapshot",
            isPresented: $showDeleteConfirm
        ) {
            Button("Delete", role: .destructive) {
                guard let token = auth.token else { return }
                Task {
                    await viewModel.delete(id: stub.id, token: token)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete \"\(stub.title)\"? This action cannot be undone.")
        }
    }

    // MARK: - Load

    private func loadDetail() async {
        guard let token = auth.token else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await viewModel.loadDetail(id: stub.id, token: token)
        } catch {
            self.error = true
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(snapshot.formattedDate)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                CardContainer(verticalPadding: 10, expandHeight: true) {
                    NetWorthDetailStatColumn(label: "Net Worth", amount: snapshot.netWorth, color: netWorthColor, delta: deltaNetWorth, previousAmount: snapshot.previousSnapshot?.netWorth)
                }
                CardContainer(verticalPadding: 10, expandHeight: true) {
                    NetWorthDetailStatColumn(label: "Assets", amount: snapshot.totalAssets, color: AppColors.income, delta: deltaAssets, previousAmount: snapshot.previousSnapshot?.totalAssets)
                }
                CardContainer(verticalPadding: 10, expandHeight: true) {
                    NetWorthDetailStatColumn(label: "Liabilities", amount: snapshot.totalLiabilities, color: AppColors.expense, delta: deltaLiabilities, previousAmount: snapshot.previousSnapshot?.totalLiabilities)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Loading Placeholder

    private var loadingPlaceholder: some View {
        CardContainer {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Entry label placeholder")
                                .font(.subheadline.weight(.medium))
                                .redacted(reason: .placeholder)
                            Text("Category")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("00.0%")
                                    .font(.caption2)
                                    .redacted(reason: .placeholder)
                                Text("€0,000.00")
                                    .font(.subheadline.weight(.semibold))
                                    .monospacedDigit()
                                    .redacted(reason: .placeholder)
                            }
                        }
                    }
                    .padding(.vertical, 8)
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
    let delta: Double?
    let previousAmount: Double?

    @State private var showPopover = false
    @Environment(ThemeManager.self) private var theme

    private var deltaPercent: Double? {
        guard let d = delta, let prev = previousAmount, prev != 0 else { return nil }
        return d / abs(prev) * 100
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if delta != nil {
                    Button { showPopover.toggle() } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showPopover) {
                        deltaPopover
                    }
                }
            }
            Text(amount.maskedCurrency(hidden: theme.hideAmounts))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var deltaPopover: some View {
        if let d = delta {
            let sign = d >= 0 ? "+" : ""
            let dColor: Color = d >= 0 ? AppColors.income : AppColors.expense
            VStack(alignment: .leading, spacing: 4) {
                Text("vs. previous snapshot")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Group {
                    if let pct = deltaPercent {
                        let pctSign = pct >= 0 ? "+" : ""
                        Text("\(sign)\(d.maskedCurrency(hidden: theme.hideAmounts)) (\(pctSign)\(String(format: "%.1f", pct))%)")
                    } else {
                        Text("\(sign)\(d.maskedCurrency(hidden: theme.hideAmounts))")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(dColor)
                .monospacedDigit()
            }
            .padding(12)
            .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Entries Section

private struct EntriesSection: View {
    let title: String
    let entries: [NetWorthEntry]
    let totalColor: Color
    let total: Double
    let previousEntries: [NetWorthEntryRef]?

    @State private var collapsed = false
    @Environment(ThemeManager.self) private var theme

    private var groupedEntries: [(category: String, entries: [NetWorthEntry])] {
        var seen = Set<String>()
        var categories = [String]()
        for entry in entries {
            if seen.insert(entry.category).inserted {
                categories.append(entry.category)
            }
        }
        let grouped = Dictionary(grouping: entries) { $0.category }
        return categories.map { (category: $0, entries: grouped[$0] ?? []) }
    }

    private func delta(for entry: NetWorthEntry) -> Double? {
        guard let prevEntries = previousEntries else { return nil }
        guard let prev = prevEntries.first(where: { $0.label == entry.label && $0.category == entry.category }) else { return nil }
        return entry.amount - prev.amount
    }

    private func isNew(_ entry: NetWorthEntry) -> Bool {
        guard let prevEntries = previousEntries else { return false }
        return !prevEntries.contains { $0.label == entry.label && $0.category == entry.category }
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text(total.maskedCurrency(hidden: theme.hideAmounts))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(totalColor)
                                .monospacedDigit()
                        }
                        Spacer()
                        Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !collapsed {
                    VStack(spacing: 8) {
                        ForEach(groupedEntries, id: \.category) { group in
                            categoryCard(category: group.category, entries: group.entries)
                        }
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    @ViewBuilder
    private func categoryCard(category: String, entries: [NetWorthEntry]) -> some View {
        VStack(spacing: 0) {
            Text(category)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Divider()
                entryRow(entry: entry)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .background(AppColors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func entryRow(entry: NetWorthEntry) -> some View {
        let entryIsNew = isNew(entry)
        let entryDelta = delta(for: entry)
        let pct = total > 0 ? entry.amount / total * 100 : 0

        HStack {
            HStack(spacing: 6) {
                Text(entry.label)
                    .font(.subheadline.weight(.medium))
                if entryIsNew {
                    Text("New")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(AppColors.income.opacity(0.15))
                        .foregroundStyle(AppColors.income)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Text(String(format: "%.1f%%", pct))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(entry.amount.maskedCurrency(hidden: theme.hideAmounts))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(totalColor)
                        .monospacedDigit()
                }
                if let d = entryDelta, !entryIsNew {
                    let deltaColor = d >= 0 ? AppColors.income : AppColors.expense
                    let sign = d >= 0 ? "+" : ""
                    HStack(spacing: 2) {
                        Image(systemName: d >= 0 ? "arrow.up" : "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                        Text("\(sign)\(d.maskedCurrency(hidden: theme.hideAmounts))")
                            .font(.caption2.monospacedDigit())
                    }
                    .foregroundStyle(deltaColor)
                }
            }
        }
    }
}
