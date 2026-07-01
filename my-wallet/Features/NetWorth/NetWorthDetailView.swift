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
            (Text("Date: ").foregroundStyle(.secondary)
                + Text(snapshot.formattedDate).foregroundStyle(.primary).fontWeight(.medium))
                .font(.subheadline)

            HStack(spacing: 8) {
                CardContainer(verticalPadding: 10, expandHeight: true) {
                    NetWorthDetailStatColumn(label: "Net Worth", amount: snapshot.netWorth, color: netWorthColor, delta: deltaNetWorth)
                }
                CardContainer(verticalPadding: 10, expandHeight: true) {
                    NetWorthDetailStatColumn(label: "Assets", amount: snapshot.totalAssets, color: AppColors.income, delta: deltaAssets)
                }
                CardContainer(verticalPadding: 10, expandHeight: true) {
                    NetWorthDetailStatColumn(label: "Liabilities", amount: snapshot.totalLiabilities, color: AppColors.expense, delta: deltaLiabilities, invertColors: true)
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
    var invertColors: Bool = false

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(amount.maskedCurrency(hidden: theme.hideAmounts))
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let d = delta, d != 0 {
                deltaLabel(d)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Inline change vs. the previous snapshot, mirroring the web header card.
    /// Liabilities invert the colours (an increase in debt is "bad").
    @ViewBuilder
    private func deltaLabel(_ d: Double) -> some View {
        let isPositive = d > 0
        let isGood = invertColors ? !isPositive : isPositive
        let deltaColor: Color = isGood ? AppColors.income : AppColors.expense
        let sign = isPositive ? "+" : "−"
        Text("\(sign)\(abs(d).maskedCurrency(hidden: theme.hideAmounts))")
            .font(.subheadline.weight(.medium).monospacedDigit())
            .foregroundStyle(deltaColor)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
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
        let grouped = Dictionary(grouping: entries) { $0.category }
        return grouped.keys
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
            .map { category in
                let sortedEntries = (grouped[category] ?? []).sorted {
                    $0.label.localizedCaseInsensitiveCompare($1.label) == .orderedAscending
                }
                return (category: category, entries: sortedEntries)
            }
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
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(total.maskedCurrency(hidden: theme.hideAmounts))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(totalColor)
                            .monospacedDigit()
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
                .font(.subheadline.weight(.semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(AppColors.surfaceMuted)

            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                Divider()
                entryRow(entry: entry)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func entryRow(entry: NetWorthEntry) -> some View {
        let entryIsNew = isNew(entry)
        let entryDelta = delta(for: entry)
        let pct = total > 0 ? entry.amount / total * 100 : 0

        HStack {
            VStack(alignment: .leading, spacing: 2) {
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
                if let notes = entry.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.amount.maskedCurrency(hidden: theme.hideAmounts))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(totalColor)
                        .monospacedDigit()
                    Text("· \(String(format: "%.1f%%", pct))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let d = entryDelta, !entryIsNew, d != 0 {
                    let deltaColor = d >= 0 ? AppColors.income : AppColors.expense
                    let sign = d >= 0 ? "+" : "−"
                    let previous = entry.amount - d
                    let pctChange: Double? = previous != 0 ? d / abs(previous) * 100 : nil
                    Group {
                        if let pc = pctChange {
                            Text("\(sign)\(abs(d).maskedCurrency(hidden: theme.hideAmounts)) (\(sign)\(String(format: "%.1f", abs(pc)))%)")
                        } else {
                            Text("\(sign)\(abs(d).maskedCurrency(hidden: theme.hideAmounts))")
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(deltaColor)
                }
            }
        }
    }
}
