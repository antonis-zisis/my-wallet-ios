import Charts
import SwiftUI

// MARK: - Sheet mode

enum NetWorthSheetMode: Identifiable {
    case create
    case edit(NetWorthSnapshot)
    case duplicate(NetWorthSnapshot)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let s): "edit-\(s.id)"
        case .duplicate(let s): "dup-\(s.id)"
        }
    }
}

// MARK: - Entry Draft

struct NetWorthEntryDraft: Identifiable {
    let id = UUID()
    var type: String
    var category: String
    var label: String
    var amount: String
    var notes: String
    var isExpanded: Bool

    init(type: String = "ASSET", category: String? = nil, label: String = "", amount: String = "", notes: String = "", isExpanded: Bool = true) {
        self.type = type
        self.category = category ?? (type == "ASSET" ? assetCategories[0] : liabilityCategories[0])
        self.label = label
        self.amount = amount
        self.notes = notes
        self.isExpanded = isExpanded
    }
}

// MARK: - Snapshot Sheet

struct NetWorthSnapshotSheet: View {
    let mode: NetWorthSheetMode
    let onCreate: (CreateNetWorthSnapshotInput) -> Void
    let onUpdate: (String, UpdateNetWorthSnapshotInput) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var snapshotDate: Date
    @State private var entries: [NetWorthEntryDraft]

    init(
        mode: NetWorthSheetMode,
        onCreate: @escaping (CreateNetWorthSnapshotInput) -> Void,
        onUpdate: @escaping (String, UpdateNetWorthSnapshotInput) -> Void
    ) {
        self.mode = mode
        self.onCreate = onCreate
        self.onUpdate = onUpdate

        switch mode {
        case .create:
            _title = State(initialValue: "")
            _snapshotDate = State(initialValue: Date())
            _entries = State(initialValue: [NetWorthEntryDraft()])
        case .edit(let snapshot):
            _title = State(initialValue: snapshot.title)
            _snapshotDate = State(initialValue: snapshot.parsedSnapshotDate)
            _entries = State(initialValue: (snapshot.entries ?? []).map {
                NetWorthEntryDraft(type: $0.type, category: $0.category, label: $0.label, amount: Self.formatAmount($0.amount), notes: $0.notes ?? "", isExpanded: false)
            })
        case .duplicate(let snapshot):
            _title = State(initialValue: "")
            _snapshotDate = State(initialValue: Date())
            _entries = State(initialValue: (snapshot.entries ?? []).map {
                NetWorthEntryDraft(type: $0.type, category: $0.category, label: $0.label, amount: Self.formatAmount($0.amount), notes: $0.notes ?? "", isExpanded: false)
            })
        }
    }

    private static func formatAmount(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
    }

    private var navigationTitle: String {
        switch mode {
        case .create: "New Snapshot"
        case .edit: "Edit Snapshot"
        case .duplicate: "Duplicate Snapshot"
        }
    }

    private var totalAssets: Double {
        entries.filter { $0.type == "ASSET" }.reduce(0) { $0 + (Double($1.amount) ?? 0) }
    }

    private var totalLiabilities: Double {
        entries.filter { $0.type == "LIABILITY" }.reduce(0) { $0 + (Double($1.amount) ?? 0) }
    }

    private var netWorth: Double { totalAssets - totalLiabilities }

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !entries.isEmpty &&
        entries.allSatisfy {
            !$0.label.trimmingCharacters(in: .whitespaces).isEmpty && (Double($0.amount) ?? 0) > 0
        }
    }

    private var isoDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: snapshotDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    fieldGroup(label: "Snapshot Title") {
                        TextField("e.g. February 2026", text: $title)
                            .autocorrectionDisabled()
                            .styledInput()
                    }

                    fieldGroup(label: "Date") {
                        DatePicker("", selection: $snapshotDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .styledInput()
                    }

                    summaryCard

                    HStack(spacing: 8) {
                        addEntryButton(label: "Add Asset", color: AppColors.income) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                for i in entries.indices { entries[i].isExpanded = false }
                                entries.insert(NetWorthEntryDraft(type: "ASSET"), at: 0)
                            }
                        }
                        addEntryButton(label: "Add Liability", color: AppColors.expense) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                for i in entries.indices { entries[i].isExpanded = false }
                                entries.insert(NetWorthEntryDraft(type: "LIABILITY"), at: 0)
                            }
                        }
                    }

                    ForEach($entries) { $entry in
                        entryCard(entry: $entry)
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { submit() }
                        .disabled(!isValid)
                }
            }
        }
    }

    @ViewBuilder
    private func entryCard(entry: Binding<NetWorthEntryDraft>) -> some View {
        let categories = entry.type.wrappedValue == "ASSET" ? assetCategories : liabilityCategories
        let typeName = entry.type.wrappedValue == "ASSET" ? "Asset" : "Liability"
        let trimmedLabel = entry.label.wrappedValue.trimmingCharacters(in: .whitespaces)
        let headerTitle = (!entry.isExpanded.wrappedValue && !trimmedLabel.isEmpty)
            ? "\(typeName) - \(trimmedLabel)"
            : typeName

        VStack(spacing: 0) {
            // Header — tappable to toggle
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    entry.isExpanded.wrappedValue.toggle()
                }
            } label: {
                HStack {
                    Text(headerTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    HStack(spacing: 12) {
                        if entry.isExpanded.wrappedValue && entries.count > 1 {
                            Button {
                                entries.removeAll { $0.id == entry.id }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.expense)
                            }
                            .buttonStyle(.plain)
                        }
                        Image(systemName: entry.isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            // Fields — visible only when expanded
            if entry.isExpanded.wrappedValue {
                Divider()

                HStack {
                    Text("Category")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("", selection: entry.category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    .labelsHidden()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                HStack {
                    Text("Label")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("e.g. Emergency Fund", text: entry.label)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                HStack {
                    Text("Notes")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("e.g. 52 shares", text: entry.notes)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                Divider()

                HStack {
                    Text("Amount")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("0.00", text: entry.amount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
    }

    private func addEntryButton(label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                Text(label)
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var summaryCard: some View {
        VStack(spacing: 0) {
            HStack {
                Label("Assets", systemImage: "arrow.up")
                    .foregroundStyle(AppColors.income)
                Spacer()
                Text(totalAssets.formatted(.currency(code: "EUR")))
                    .foregroundStyle(AppColors.income)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            HStack {
                Label("Liabilities", systemImage: "arrow.down")
                    .foregroundStyle(AppColors.expense)
                Spacer()
                Text(totalLiabilities.formatted(.currency(code: "EUR")))
                    .foregroundStyle(AppColors.expense)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            HStack {
                Text("Net Worth")
                    .fontWeight(.semibold)
                Spacer()
                Text(netWorth.formatted(.currency(code: "EUR")))
                    .fontWeight(.semibold)
                    .foregroundStyle(netWorth >= 0 ? AppColors.income : AppColors.expense)
                    .monospacedDigit()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
    }

    @ViewBuilder
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func submit() {
        let entryInputs = entries.map {
            NetWorthEntryInput(
                type: $0.type,
                label: $0.label.trimmingCharacters(in: .whitespaces),
                amount: Double($0.amount) ?? 0,
                category: $0.category,
                notes: $0.notes.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil
                    : $0.notes.trimmingCharacters(in: .whitespaces)
            )
        }
        switch mode {
        case .create, .duplicate:
            onCreate(CreateNetWorthSnapshotInput(
                title: title.trimmingCharacters(in: .whitespaces),
                snapshotDate: isoDate,
                entries: entryInputs
            ))
        case .edit(let snapshot):
            onUpdate(snapshot.id, UpdateNetWorthSnapshotInput(
                title: title.trimmingCharacters(in: .whitespaces),
                snapshotDate: isoDate,
                entries: entryInputs
            ))
        }
        dismiss()
    }
}

// MARK: - Styled input

private extension View {
    func styledInput() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
    }
}

// MARK: - Chart mode

private enum NetWorthChartMode: String, CaseIterable {
    case netWorth = "Net Worth"
    case breakdown = "Assets & Liabilities"
}

// MARK: - Trend Chart Card

private struct TrendChartCard: View {
    let snapshots: [NetWorthSnapshot]

    @State private var collapsed = true
    @State private var mode: NetWorthChartMode = .netWorth
    @State private var showInfo = false
    @Environment(ThemeManager.self) private var theme

    private var chartData: [NetWorthSnapshot] {
        Array(snapshots.prefix(10).reversed())
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
                } label: {
                    HStack {
                        Text("Net Worth Over Time")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 8) {
                            Button {
                                showInfo.toggle()
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showInfo) {
                                Text("Showing the \(chartData.count) most recent snapshots, from oldest to newest.")
                                    .font(.subheadline)
                                    .padding(12)
                                    .presentationCompactAdaptation(.popover)
                            }
                            Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if !collapsed {
                    HStack(spacing: 0) {
                        ForEach(NetWorthChartMode.allCases, id: \.self) { option in
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) { mode = option }
                            } label: {
                                Text(option.rawValue)
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 7)
                                    .background(
                                        mode == option ? AppColors.surface : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 3)
                                    )
                                    .foregroundStyle(mode == option ? AppColors.textPrimary : AppColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(3)
                    .background(AppColors.surfaceMuted, in: RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
                    .padding(.top, 14)
                    .padding(.bottom, 30)

                    if mode == .netWorth {
                        netWorthChart
                    } else {
                        breakdownChart
                    }
                }
            }
        }
    }

    private var netWorthChart: some View {
        Chart {
            ForEach(chartData) { snapshot in
                AreaMark(
                    x: .value("Date", snapshot.parsedSnapshotDate),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(AppColors.brand.opacity(0.12))
            }
            ForEach(chartData) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.parsedSnapshotDate),
                    y: .value("Net Worth", snapshot.netWorth)
                )
                .foregroundStyle(AppColors.brand)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 160)
    }

    private var breakdownChart: some View {
        Chart {
            ForEach(chartData) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.parsedSnapshotDate),
                    y: .value("Value", snapshot.totalAssets),
                    series: .value("Type", "Assets")
                )
                .foregroundStyle(AppColors.income)
            }
            ForEach(chartData) { snapshot in
                LineMark(
                    x: .value("Date", snapshot.parsedSnapshotDate),
                    y: .value("Value", snapshot.totalLiabilities),
                    series: .value("Type", "Liabilities")
                )
                .foregroundStyle(AppColors.expense)
            }
        }
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel(format: .dateTime.month(.abbreviated).year(.twoDigits))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .frame(height: 160)
    }
}

// MARK: - Snapshot Row

private struct SnapshotRow: View {
    let snapshot: NetWorthSnapshot

    @Environment(ThemeManager.self) private var theme

    private var netWorthColor: Color { snapshot.netWorth >= 0 ? AppColors.income : AppColors.expense }

    private var delta: Double? {
        guard let prev = snapshot.previousSnapshot?.netWorth else { return nil }
        return snapshot.netWorth - prev
    }

    private var deltaPercent: Double? {
        guard let prev = snapshot.previousSnapshot?.netWorth, prev != 0 else { return nil }
        return (snapshot.netWorth - prev) / abs(prev) * 100
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                // Row 1: Title · Date
                (Text(snapshot.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary) +
                 Text("  ·  ")
                    .font(.caption)
                    .foregroundStyle(Color.secondary) +
                 Text(snapshot.formattedDate)
                    .font(.caption)
                    .foregroundStyle(Color.secondary))
                .lineLimit(1)

                // Row 2: Net Worth
                netWorthText
                    .font(.caption)
                    .monospacedDigit()

                // Row 3: Change (only when previous snapshot exists)
                if let d = delta, let pct = deltaPercent {
                    changeText(delta: d, percent: pct)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textTertiary)
                .padding(.leading, 8)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private var netWorthText: Text {
        let sign = snapshot.netWorth >= 0 ? "+" : ""
        return Text("Net Worth: ").foregroundStyle(Color.secondary) +
               Text("\(sign)\(snapshot.netWorth.maskedCurrency(hidden: theme.hideAmounts))")
                   .foregroundStyle(netWorthColor)
    }

    private func changeText(delta d: Double, percent pct: Double) -> Text {
        let dSign = d >= 0 ? "+" : ""
        let dColor: Color = d >= 0 ? AppColors.income : AppColors.expense
        let pctSign = pct >= 0 ? "+" : ""
        let str = "\(dSign)\(d.maskedCurrency(hidden: theme.hideAmounts)) (\(pctSign)\(String(format: "%.1f", pct))%)"
        return Text("Change: ").foregroundStyle(Color.secondary) +
               Text(str).foregroundStyle(dColor)
    }
}

// MARK: - Net Worth View

struct NetWorthView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = NetWorthViewModel()
    @State private var sheetMode: NetWorthSheetMode?
    @State private var snapshotToDelete: NetWorthSnapshot?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if viewModel.isLoading {
                    loadingPlaceholder
                        .padding()
                } else if viewModel.error {
                    Text("Failed to load snapshots.")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else if viewModel.snapshots.isEmpty {
                    emptyState
                        .padding()
                } else {
                    VStack(spacing: 12) {
                        if viewModel.snapshots.count >= 2 {
                            TrendChartCard(snapshots: viewModel.snapshots)
                        }
                        controls
                        if viewModel.visibleSnapshots.isEmpty {
                            noMatchesState
                        } else {
                            snapshotList
                        }
                    }
                    .padding()
                }
            }
        }
        .background(AppColors.bgApp)
        .refreshable {
            guard let token = auth.token else { return }
            await viewModel.load(token: token)
        }
        .navigationTitle("Net Worth")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { sheetMode = .create } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .task {
            guard let token = auth.token else { return }
            await viewModel.load(token: token)
        }
        .sheet(item: $sheetMode) { mode in
            NetWorthSnapshotSheet(
                mode: mode,
                onCreate: { input in
                    guard let token = auth.token else { return }
                    Task { await viewModel.create(input: input, token: token) }
                },
                onUpdate: { id, input in
                    guard let token = auth.token else { return }
                    Task { try? await viewModel.update(id: id, input: input, token: token) }
                }
            )
        }
        .alert(
            "Delete Snapshot",
            isPresented: Binding(get: { snapshotToDelete != nil }, set: { if !$0 { snapshotToDelete = nil } }),
            presenting: snapshotToDelete
        ) { snapshot in
            Button("Delete", role: .destructive) {
                guard let token = auth.token else { return }
                Task { await viewModel.delete(id: snapshot.id, token: token) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { snapshot in
            Text("Are you sure you want to permanently delete \"\(snapshot.title)\"? This action cannot be undone.")
        }
    }

    // MARK: - Subviews

    private var controls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search snapshots…", text: $viewModel.searchText)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))

            Menu {
                Picker("Sort", selection: $viewModel.sortOption) {
                    ForEach(NetWorthSortOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(width: 44)
                    .frame(maxHeight: .infinity)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
            }
            .fixedSize(horizontal: true, vertical: false)
        }
    }

    private var snapshotList: some View {
        CardContainer(verticalPadding: 4) {
            VStack(spacing: 0) {
                let snapshots = viewModel.visibleSnapshots
                ForEach(Array(snapshots.enumerated()), id: \.element.id) { index, snapshot in
                    NavigationLink {
                        NetWorthDetailView(stub: snapshot, viewModel: viewModel)
                    } label: {
                        SnapshotRow(snapshot: snapshot)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            snapshotToDelete = snapshot
                        }
                    }
                    if index < snapshots.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No snapshots match your search.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(AppColors.border)
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No snapshots yet.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Button("Add your first snapshot") {
                sheetMode = .create
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(AppColors.border)
        )
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 12) {
            // Chart card skeleton (collapsed header)
            CardContainer {
                HStack {
                    Text("Net Worth Over Time")
                        .font(.headline)
                        .redacted(reason: .placeholder)
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary.opacity(0.4))
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary.opacity(0.4))
                    }
                }
            }

            // Snapshot list skeleton
            CardContainer(verticalPadding: 4) {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        HStack(alignment: .center, spacing: 0) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Snapshot title  ·  Jan 1, 2025")
                                    .font(.subheadline.weight(.medium))
                                    .redacted(reason: .placeholder)
                                Text("Net Worth: +€0,000.00")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .redacted(reason: .placeholder)
                                Text("Change: +€000.00 (+0.0%)")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .redacted(reason: .placeholder)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textTertiary.opacity(0.4))
                                .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                        if index < 4 { Divider() }
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NetWorthView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
}
