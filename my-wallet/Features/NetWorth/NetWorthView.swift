import SwiftUI

// MARK: - Entry Draft

private struct EntryDraft: Identifiable {
    let id = UUID()
    var type: String = "ASSET"
    var category: String = assetCategories[0]
    var label: String = ""
    var amount: String = ""
}

// MARK: - Create Snapshot Sheet

private struct CreateNetWorthSnapshotSheet: View {
    let onSubmit: (CreateNetWorthSnapshotInput) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var entries: [EntryDraft] = [EntryDraft()]

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

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") {
                    TextField("e.g. February 2026", text: $title)
                        .autocorrectionDisabled()
                }

                ForEach($entries) { $entry in
                    entrySection(entry: $entry)
                }

                Section {
                    Button("+ Add Asset") {
                        entries.append(EntryDraft())
                    }
                    Button("+ Add Liability") {
                        var draft = EntryDraft()
                        draft.type = "LIABILITY"
                        draft.category = liabilityCategories[0]
                        entries.append(draft)
                    }
                }

                Section("Summary") {
                    HStack {
                        Label("Assets", systemImage: "arrow.up")
                            .foregroundStyle(.green)
                        Spacer()
                        Text(totalAssets.formatted(.currency(code: "EUR")))
                            .foregroundStyle(.green)
                            .monospacedDigit()
                    }
                    HStack {
                        Label("Liabilities", systemImage: "arrow.down")
                            .foregroundStyle(.red)
                        Spacer()
                        Text(totalLiabilities.formatted(.currency(code: "EUR")))
                            .foregroundStyle(.red)
                            .monospacedDigit()
                    }
                    HStack {
                        Text("Net Worth")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(netWorth.formatted(.currency(code: "EUR")))
                            .fontWeight(.semibold)
                            .foregroundStyle(netWorth >= 0 ? Color.green : Color.red)
                            .monospacedDigit()
                    }
                }
            }
            .navigationTitle("New Snapshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let input = CreateNetWorthSnapshotInput(
                            title: title.trimmingCharacters(in: .whitespaces),
                            entries: entries.map {
                                NetWorthEntryInput(
                                    type: $0.type,
                                    label: $0.label.trimmingCharacters(in: .whitespaces),
                                    amount: Double($0.amount) ?? 0,
                                    category: $0.category
                                )
                            }
                        )
                        onSubmit(input)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    @ViewBuilder
    private func entrySection(entry: Binding<EntryDraft>) -> some View {
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
                ForEach(categories, id: \.self) { cat in
                    Text(cat).tag(cat)
                }
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
}

// MARK: - Snapshot Row

private struct SnapshotRow: View {
    let snapshot: NetWorthSnapshot

    private var netWorthColor: Color { snapshot.netWorth >= 0 ? .green : .red }
    private var sign: String { snapshot.netWorth >= 0 ? "+" : "" }

    var body: some View {
        HStack {
            Text(snapshot.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(sign)\(snapshot.netWorth.formatted(.currency(code: "EUR")))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(netWorthColor)
                    .monospacedDigit()
                Text(snapshot.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Net Worth View

struct NetWorthView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = NetWorthViewModel()
    @State private var showCreate = false
    @State private var snapshotToDelete: NetWorthSnapshot?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
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
                        snapshotList
                            .padding()
                    }
                }
            }
            .refreshable {
                guard let token = auth.token else { return }
                await viewModel.load(token: token)
            }
            .navigationTitle("Net Worth")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                guard let token = auth.token else { return }
                await viewModel.load(token: token)
            }
        }
        .sheet(isPresented: $showCreate) {
            CreateNetWorthSnapshotSheet { input in
                guard let token = auth.token else { return }
                Task { await viewModel.create(input: input, token: token) }
            }
        }
        .alert(
            "Delete Snapshot",
            isPresented: Binding(
                get: { snapshotToDelete != nil },
                set: { if !$0 { snapshotToDelete = nil } }
            ),
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
                                .foregroundStyle(Color(.tertiaryLabel))
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
                showCreate = true
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundStyle(Color.secondary.opacity(0.3))
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
