import SwiftUI

struct ReportDetailView: View {
    let stub: Report
    var onUpdate: ((Report) -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ReportDetailViewModel()
    @State private var showRenameSheet = false
    @State private var showDeleteConfirm = false
    @State private var isPerformingAction = false

    /// Always use the loaded report when available so mutations are reflected immediately.
    private var report: Report { viewModel.report ?? stub }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                metadataCard

                if viewModel.isLoading {
                    loadingContent
                } else if let loaded = viewModel.report {
                    SummaryCards(report: loaded)
                    TransactionSection(transactions: loaded.transactions ?? [])
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
        .navigationTitle(report.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showRenameSheet) {
            RenameReportSheet(currentTitle: report.title) { newTitle in
                try await performRename(newTitle: newTitle)
            }
        }
        .confirmationDialog(
            "Delete \"\(report.title)\"?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Report", role: .destructive) {
                Task { await performDelete() }
            }
        } message: {
            Text("This action cannot be undone.")
        }
        .task {
            guard let token = auth.token else { return }
            await viewModel.loadReport(id: stub.id, token: token)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            if isPerformingAction {
                ProgressView()
            } else if !viewModel.isLoading {
                Menu {
                    if !report.isLocked {
                        Button("Rename Report", systemImage: "pencil") {
                            showRenameSheet = true
                        }
                        Button("Lock Report", systemImage: "lock") {
                            Task { await performLock() }
                        }
                        Divider()
                        Button("Delete Report", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } else {
                        Button("Unlock Report", systemImage: "lock.open") {
                            Task { await performUnlock() }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
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
                    Text(report.formattedCreatedAt)
                        .font(.caption.weight(.medium))
                }
                Divider()
                HStack {
                    Text("Updated")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(report.formattedUpdatedAt)
                        .font(.caption.weight(.medium))
                }
                if report.isLocked {
                    Divider()
                    HStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Locked")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
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

    // MARK: - Actions

    private func performRename(newTitle: String) async throws {
        guard let token = auth.token else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        try await viewModel.renameReport(id: report.id, newTitle: newTitle, token: token)
        onUpdate?(viewModel.report ?? stub)
    }

    private func performLock() async {
        guard let token = auth.token else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        try? await viewModel.lockReport(id: report.id, token: token)
        onUpdate?(viewModel.report ?? stub)
    }

    private func performUnlock() async {
        guard let token = auth.token else { return }
        isPerformingAction = true
        defer { isPerformingAction = false }
        try? await viewModel.unlockReport(id: report.id, token: token)
        onUpdate?(viewModel.report ?? stub)
    }

    private func performDelete() async {
        guard let token = auth.token else { return }
        isPerformingAction = true
        do {
            try await viewModel.deleteReport(id: report.id, token: token)
            onDelete?()
            dismiss()
        } catch {
            isPerformingAction = false
        }
    }
}

// MARK: - Rename Sheet

private struct RenameReportSheet: View {
    let currentTitle: String
    let onRename: (String) async throws -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var isSubmitting = false
    @State private var error: String?

    private let minLength = 3
    private let maxLength = 100

    init(currentTitle: String, onRename: @escaping (String) async throws -> Void) {
        self.currentTitle = currentTitle
        self.onRename = onRename
        _title = State(initialValue: currentTitle)
    }

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool {
        trimmed.count >= minLength && trimmed.count <= maxLength && trimmed != currentTitle
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Report title", text: $title)
                        .autocorrectionDisabled()
                } header: {
                    Text("Report Title")
                } footer: {
                    Text("\(title.count)/\(maxLength) · Between \(minLength)–\(maxLength) characters")
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle("Rename Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Group {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Button("Save") {
                                Task { await submit() }
                            }
                            .fontWeight(.semibold)
                            .disabled(!isValid)
                        }
                    }
                }
            }
            .disabled(isSubmitting)
        }
    }

    private func submit() async {
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }
        do {
            try await onRename(trimmed)
            dismiss()
        } catch {
            self.error = error.localizedDescription
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
