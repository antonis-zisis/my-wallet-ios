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

    init(type: String = "ASSET", category: String? = nil, label: String = "", amount: String = "") {
        self.type = type
        self.category = category ?? (type == "ASSET" ? assetCategories[0] : liabilityCategories[0])
        self.label = label
        self.amount = amount
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
                NetWorthEntryDraft(type: $0.type, category: $0.category, label: $0.label, amount: Self.formatAmount($0.amount))
            })
        case .duplicate(let snapshot):
            _title = State(initialValue: "")
            _snapshotDate = State(initialValue: Date())
            _entries = State(initialValue: (snapshot.entries ?? []).map {
                NetWorthEntryDraft(type: $0.type, category: $0.category, label: $0.label, amount: Self.formatAmount($0.amount))
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
            Form {
                Section("Title") {
                    TextField("e.g. February 2026", text: $title)
                        .autocorrectionDisabled()
                }

                Section("Date") {
                    DatePicker("Snapshot Date", selection: $snapshotDate, displayedComponents: .date)
                        .labelsHidden()
                }

                ForEach($entries) { $entry in
                    entrySection(entry: $entry)
                }

                Section {
                    Button("+ Add Asset") {
                        entries.append(NetWorthEntryDraft())
                    }
                    Button("+ Add Liability") {
                        entries.append(NetWorthEntryDraft(type: "LIABILITY"))
                    }
                }

                Section("Summary") {
                    HStack {
                        Label("Assets", systemImage: "arrow.up")
                            .foregroundStyle(AppColors.income)
                        Spacer()
                        Text(totalAssets.formatted(.currency(code: "EUR")))
                            .foregroundStyle(AppColors.income)
                            .monospacedDigit()
                    }
                    HStack {
                        Label("Liabilities", systemImage: "arrow.down")
                            .foregroundStyle(AppColors.expense)
                        Spacer()
                        Text(totalLiabilities.formatted(.currency(code: "EUR")))
                            .foregroundStyle(AppColors.expense)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Net Worth")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(netWorth.formatted(.currency(code: "EUR")))
                            .fontWeight(.semibold)
                            .foregroundStyle(netWorth >= 0 ? AppColors.income : AppColors.expense)
                            .monospacedDigit()
                    }
                }
            }
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
    private func entrySection(entry: Binding<NetWorthEntryDraft>) -> some View {
        let categories = entry.type.wrappedValue == "ASSET" ? assetCategories : liabilityCategories
        Section {
            Picker("Type", selection: entry.type) {
                Text("Asset").tag("ASSET")
                Text("Liability").tag("LIABILITY")
            }
            .pickerStyle(.segmented)
            .onChange(of: entry.type.wrappedValue) { _, newType in
                entry.category.wrappedValue = newType == "ASSET" ? assetCategories[0] : liabilityCategories[0]
            }

            Picker("Category", selection: entry.category) {
                ForEach(categories, id: \.self) { Text($0).tag($0) }
            }

            TextField("Label", text: entry.label)
                .autocorrectionDisabled()

            TextField("Amount", text: entry.amount)
                .keyboardType(.decimalPad)
        } header: {
            HStack {
                Text(entry.type.wrappedValue == "ASSET" ? "Asset" : "Liability")
                Spacer()
                if entries.count > 1 {
                    Button(role: .destructive) {
                        entries.removeAll { $0.id == entry.id }
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private func submit() {
        let entryInputs = entries.map {
            NetWorthEntryInput(
                type: $0.type,
                label: $0.label.trimmingCharacters(in: .whitespaces),
                amount: Double($0.amount) ?? 0,
                category: $0.category
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

// MARK: - Chart mode

private enum NetWorthChartMode: String, CaseIterable {
    case netWorth = "Net Worth"
    case breakdown = "Assets & Liabilities"
}

// MARK: - Trend Chart Card

private struct TrendChartCard: View {
    let snapshots: [NetWorthSnapshot]

    @State private var collapsed = false
    @State private var mode: NetWorthChartMode = .netWorth
    @Environment(ThemeManager.self) private var theme

    private var chartData: [NetWorthSnapshot] {
        Array(snapshots.prefix(10).reversed())
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Trend")
                        .font(.headline)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { collapsed.toggle() }
                    } label: {
                        Image(systemName: collapsed ? "chevron.down" : "chevron.up")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                if !collapsed {
                    Picker("", selection: $mode) {
                        ForEach(NetWorthChartMode.allCases, id: \.self) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)

                    Chart {
                        if mode == .netWorth {
                            ForEach(chartData) { snapshot in
                                LineMark(
                                    x: .value("Date", snapshot.parsedSnapshotDate),
                                    y: .value("Net Worth", snapshot.netWorth)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(AppColors.brand)

                                AreaMark(
                                    x: .value("Date", snapshot.parsedSnapshotDate),
                                    y: .value("Net Worth", snapshot.netWorth)
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(AppColors.brand.opacity(0.12))
                            }
                        } else {
                            ForEach(chartData) { snapshot in
                                LineMark(
                                    x: .value("Date", snapshot.parsedSnapshotDate),
                                    y: .value("Assets", snapshot.totalAssets),
                                    series: .value("Type", "Assets")
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(AppColors.income)

                                LineMark(
                                    x: .value("Date", snapshot.parsedSnapshotDate),
                                    y: .value("Liabilities", snapshot.totalLiabilities),
                                    series: .value("Type", "Liabilities")
                                )
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(AppColors.expense)
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) {
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
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
        }
    }
}

// MARK: - Snapshot Row

private struct SnapshotRow: View {
    let snapshot: NetWorthSnapshot

    @Environment(ThemeManager.self) private var theme

    private var netWorthColor: Color { snapshot.netWorth >= 0 ? AppColors.income : AppColors.expense }
    private var sign: String { snapshot.netWorth >= 0 ? "+" : "" }

    private var delta: Double? {
        guard let prev = snapshot.previousSnapshot?.netWorth else { return nil }
        return snapshot.netWorth - prev
    }

    private var deltaPercent: Double? {
        guard let prev = snapshot.previousSnapshot?.netWorth, prev != 0 else { return nil }
        return (snapshot.netWorth - prev) / abs(prev) * 100
    }

    var body: some View {
        HStack {
            Text(snapshot.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(sign)\(snapshot.netWorth.maskedCurrency(hidden: theme.hideAmounts))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(netWorthColor)
                    .monospacedDigit()
                HStack(spacing: 6) {
                    if let d = delta, let pct = deltaPercent {
                        HStack(spacing: 2) {
                            Image(systemName: d >= 0 ? "arrow.up" : "arrow.down")
                                .font(.system(size: 9, weight: .bold))
                            Text(String(format: "%.1f%%", abs(pct)))
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(d >= 0 ? AppColors.income : AppColors.expense)
                    }
                    Text(snapshot.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Net Worth View

struct NetWorthView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = NetWorthViewModel()
    @State private var sheetMode: NetWorthSheetMode?
    @State private var snapshotToDelete: NetWorthSnapshot?

    var body: some View {
        NavigationStack {
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
                            snapshotList
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

    private var snapshotList: some View {
        CardContainer {
            VStack(spacing: 0) {
                ForEach(Array(viewModel.snapshots.enumerated()), id: \.element.id) { index, snapshot in
                    NavigationLink {
                        NetWorthDetailView(stub: snapshot, viewModel: viewModel)
                    } label: {
                        HStack(spacing: 0) {
                            SnapshotRow(snapshot: snapshot)
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textTertiary)
                                .padding(.leading, 8)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            snapshotToDelete = snapshot
                        }
                    }
                    if index < viewModel.snapshots.count - 1 {
                        Divider()
                    }
                }
            }
        }
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
        CardContainer {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    HStack {
                        Text("Snapshot title placeholder")
                            .font(.subheadline)
                            .redacted(reason: .placeholder)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("+€0,000.00")
                                .font(.subheadline)
                                .redacted(reason: .placeholder)
                            Text("Jan 1, 2025")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                        }
                    }
                    .padding(.vertical, 12)
                    if index < 4 { Divider() }
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
