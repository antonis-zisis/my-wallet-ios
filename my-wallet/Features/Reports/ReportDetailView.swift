import SwiftUI

// MARK: - TransactionFormMode

private enum TransactionFormMode: Identifiable {
    case create(reportId: String)
    case edit(Transaction)

    var id: String {
        switch self {
        case .create(let rid): return "create-\(rid)"
        case .edit(let t): return "edit-\(t.id)"
        }
    }

    var reportId: String {
        switch self {
        case .create(let rid): return rid
        case .edit(let t): return t.reportId
        }
    }

    var transaction: Transaction? {
        if case .edit(let t) = self { return t }
        return nil
    }
}

// MARK: - ReportDetailView

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
    @State private var transactionFormMode: TransactionFormMode? = nil
    @State private var deletingTransaction: Transaction? = nil

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
                    ExpenseBreakdownChart(transactions: loaded.transactions ?? [])
                    BudgetBreakdownChart(transactions: loaded.transactions ?? [])
                    TransactionSection(
                        transactions: loaded.transactions ?? [],
                        isLocked: loaded.isLocked,
                        onAdd: { transactionFormMode = .create(reportId: loaded.id) },
                        onEdit: { t in transactionFormMode = .edit(t) },
                        onDeleteRequest: { t in deletingTransaction = t }
                    )
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
        .refreshable {
            guard let token = auth.token else { return }
            await viewModel.loadReport(id: stub.id, token: token)
        }
        .navigationTitle(report.title)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showRenameSheet) {
            RenameReportSheet(
                reportId: report.id,
                currentTitle: report.title,
                viewModel: viewModel
            ) { updatedReport in
                onUpdate?(updatedReport)
            }
        }
        .sheet(item: $transactionFormMode) { mode in
            TransactionFormSheet(mode: mode, viewModel: viewModel)
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
        .confirmationDialog(
            "Delete transaction?",
            isPresented: Binding(
                get: { deletingTransaction != nil },
                set: { if !$0 { deletingTransaction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                guard let t = deletingTransaction else { return }
                deletingTransaction = nil
                Task { await performDeleteTransaction(t) }
            }
        } message: {
            if let t = deletingTransaction {
                Text("Delete \"\(t.description)\"? This cannot be undone.")
            }
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
                    Image(systemName: report.isLocked ? "lock.fill" : "ellipsis.circle")
                        .foregroundStyle(report.isLocked ? Color.secondary : Color.accentColor)
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

            ForEach(["Expense Breakdown", "Budget Breakdown"], id: \.self) { title in
                CardContainer {
                    HStack {
                        Text(title)
                            .font(.headline)
                            .redacted(reason: .placeholder)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
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

    private func performDeleteTransaction(_ transaction: Transaction) async {
        guard let token = auth.token else { return }
        try? await viewModel.deleteTransaction(id: transaction.id, token: token)
    }
}

// MARK: - Rename Sheet

private struct RenameReportSheet: View {
    let reportId: String
    let currentTitle: String
    let viewModel: ReportDetailViewModel
    var onComplete: ((Report) -> Void)? = nil

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var isSubmitting = false
    @State private var error: String?

    private let minLength = 3
    private let maxLength = 100

    init(reportId: String, currentTitle: String, viewModel: ReportDetailViewModel, onComplete: ((Report) -> Void)? = nil) {
        self.reportId = reportId
        self.currentTitle = currentTitle
        self.viewModel = viewModel
        self.onComplete = onComplete
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

    @MainActor
    private func submit() async {
        guard let token = auth.token else { return }
        isSubmitting = true
        error = nil
        do {
            try await viewModel.renameReport(id: reportId, newTitle: trimmed, token: token)
            if let updated = viewModel.report { onComplete?(updated) }
            dismiss()
        } catch {
            isSubmitting = false
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Transaction Form Sheet

private struct TransactionFormSheet: View {
    let mode: TransactionFormMode
    let viewModel: ReportDetailViewModel

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var type: TransactionType
    @State private var amountText: String
    @State private var descriptionText: String
    @State private var category: String
    @State private var date: Date
    @State private var isSubmitting = false
    @State private var error: String?

    private let expenseCategories = ["Rent", "Utilities", "Groceries", "Dining Out", "Transport",
                                     "Health", "Entertainment", "Shopping", "Investment",
                                     "Insurance", "Loan", "Other"]
    private let incomeCategories = ["Salary", "Freelance", "Investment", "Gift", "Other"]

    private var isEditMode: Bool {
        if case .edit = mode { return true }
        return false
    }
    private var categories: [String] { type == .expense ? expenseCategories : incomeCategories }
    private var parsedAmount: Double? {
        Double(amountText.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool {
        guard let parsedAmount, parsedAmount > 0 else { return false }
        return !descriptionText.trimmingCharacters(in: .whitespaces).isEmpty && !category.isEmpty
    }

    init(mode: TransactionFormMode, viewModel: ReportDetailViewModel) {
        self.mode = mode
        self.viewModel = viewModel
        if let t = mode.transaction {
            _type = State(initialValue: t.type)
            let amt = t.amount
            _amountText = State(initialValue: amt.truncatingRemainder(dividingBy: 1) == 0
                ? String(Int(amt)) : String(amt))
            _descriptionText = State(initialValue: t.description)
            _category = State(initialValue: t.category)
            _date = State(initialValue: t.dateAsDate)
        } else {
            _type = State(initialValue: .expense)
            _amountText = State(initialValue: "")
            _descriptionText = State(initialValue: "")
            _category = State(initialValue: "")
            _date = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        Text("Income").tag(TransactionType.income)
                        Text("Expense").tag(TransactionType.expense)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { _, _ in category = "" }
                } header: {
                    Text("Type")
                }

                Section {
                    TextField("0.00", text: $amountText)
                        .keyboardType(.decimalPad)
                    TextField("Description", text: $descriptionText)
                        .autocorrectionDisabled()
                    Picker("Category", selection: $category) {
                        Text("Select a category").tag("")
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                } header: {
                    Text("Details")
                }

                if let error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .navigationTitle(isEditMode ? "Edit Transaction" : "Add Transaction")
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
                            Button(isEditMode ? "Save" : "Add") {
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

    @MainActor
    private func submit() async {
        guard let token = auth.token, let amount = parsedAmount else { return }
        isSubmitting = true
        error = nil

        let dateStr = ISO8601DateFormatter().string(from: date)
        let typeStr = type.rawValue
        let trimmedDesc = descriptionText.trimmingCharacters(in: .whitespaces)

        do {
            switch mode {
            case .create(let reportId):
                try await viewModel.createTransaction(
                    reportId: reportId, type: typeStr, amount: amount,
                    description: trimmedDesc, category: category, date: dateStr, token: token
                )
            case .edit(let t):
                try await viewModel.updateTransaction(
                    id: t.id, type: typeStr, amount: amount,
                    description: trimmedDesc, category: category, date: dateStr, token: token
                )
            }
            dismiss()
        } catch {
            isSubmitting = false
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
    let isLocked: Bool
    let onAdd: () -> Void
    let onEdit: (Transaction) -> Void
    let onDeleteRequest: (Transaction) -> Void

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
                if !isLocked {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .imageScale(.large)
                    }
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
                let sorted = transactions.sorted { $0.dateAsDate > $1.dateAsDate }
                CardContainer {
                    VStack(spacing: 0) {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { index, transaction in
                            if index > 0 { Divider() }
                            TransactionRow(
                                transaction: transaction,
                                isLocked: isLocked,
                                onEdit: { onEdit(transaction) },
                                onDeleteRequest: { onDeleteRequest(transaction) }
                            )
                        }
                    }
                }
            }
        }
    }
}

private struct TransactionRow: View {
    let transaction: Transaction
    let isLocked: Bool
    let onEdit: () -> Void
    let onDeleteRequest: () -> Void

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
            if !isLocked {
                Menu {
                    Button("Edit", systemImage: "pencil") { onEdit() }
                    Button("Delete", systemImage: "trash", role: .destructive) { onDeleteRequest() }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
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
