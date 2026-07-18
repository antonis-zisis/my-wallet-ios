import SwiftUI

// MARK: - Category Constants

private let expenseCategories = ["Rent", "Utilities", "Groceries", "Dining Out", "Transport",
                                 "Health", "Entertainment", "Shopping", "Investment",
                                 "Insurance", "Loan", "Other"]
private let incomeCategories = ["Salary", "Freelance", "Investment", "Gift", "Other"]
private let orderedCategories: [String] = {
    var seen = Set<String>()
    return (expenseCategories + incomeCategories).filter { seen.insert($0).inserted }
}()

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
    @State private var showShareSheet = false
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
        .background(AppColors.bgApp)
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
        .sheet(isPresented: $showShareSheet) {
            ShareReportSheet(reportStub: report, viewModel: viewModel) {
                onDelete?()
                dismiss()
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
                    if !report.isLocked && report.canEdit {
                        Button("Rename Report", systemImage: "pencil") {
                            showRenameSheet = true
                        }
                    }
                    if report.isOwner {
                        if report.isLocked {
                            Button("Unlock Report", systemImage: "lock.open") {
                                Task { await performUnlock() }
                            }
                        } else {
                            Button("Lock Report", systemImage: "lock") {
                                Task { await performLock() }
                            }
                        }
                    }
                    Button(report.isOwner ? "Share Report" : "Members", systemImage: "person.2") {
                        showShareSheet = true
                    }
                    if report.isOwner && !report.isLocked {
                        Divider()
                        Button("Delete Report", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    }
                } label: {
                    Image(systemName: report.isLocked ? "lock.fill" : "ellipsis.circle")
                        .foregroundStyle(report.isLocked ? Color.secondary : Color.accentColor)
                }
            }
        }
    }

    // MARK: - Metadata Caption

    private var metadataCard: some View {
        Text("Created \(report.formattedCreatedAt) · Updated \(report.smartUpdatedAt)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
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

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Report Title")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                TextField("Report title", text: $title)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isFocused ? AppColors.borderStrong : AppColors.border, lineWidth: 1)
                    )
                    .focused($isFocused)
                Text("\(title.count)/\(maxLength) · Between \(minLength)–\(maxLength) characters")
                    .font(.caption)
                    .foregroundStyle(AppColors.textTertiary)
                if let error {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(AppColors.bgApp)
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
    @State private var showDatePicker = false

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
            ScrollView {
                VStack(spacing: 16) {
                    CardContainer {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 0) {
                                typeToggleButton(.income, label: "Income")
                                typeToggleButton(.expense, label: "Expense")
                            }
                            .padding(3)
                            .background(AppColors.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.border, lineWidth: 1))
                            .animation(.easeInOut(duration: 0.15), value: type)
                        }
                    }

                    CardContainer {
                        VStack(alignment: .leading, spacing: 14) {
                            FormField(label: "Amount") {
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .styledInput()
                            }

                            FormField(label: "Description") {
                                TextField("Description", text: $descriptionText)
                                    .autocorrectionDisabled()
                                    .styledInput()
                            }

                            FormField(label: "Category") {
                                Menu {
                                    Picker("", selection: $category) {
                                        Text("Select a category").tag("")
                                        ForEach(categories, id: \.self) { cat in
                                            Text(cat).tag(cat)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(category.isEmpty ? "Select a category" : category)
                                            .foregroundStyle(category.isEmpty ? AppColors.textTertiary : .primary)
                                        Spacer()
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .styledInput()
                                }
                                .buttonStyle(.plain)
                            }

                            FormField(label: "Date") {
                                Button {
                                    showDatePicker = true
                                } label: {
                                    HStack {
                                        Text(date.appFormatted)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .styledInput()
                                }
                                .buttonStyle(.plain)

                            }
                        }
                    }

                    if let error {
                        Text(error)
                            .font(.callout)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(20)
            }
            .background(AppColors.bgApp)
            .sheet(isPresented: $showDatePicker) {
                VStack(spacing: 0) {
                    HStack {
                        Spacer()
                        Button("Done") { showDatePicker = false }
                            .fontWeight(.semibold)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                    }
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                        .padding(.horizontal, 8)
                }
                .presentationBackground(AppColors.bgApp)
                .presentationDetents([.height(420)])
                .presentationDragIndicator(.visible)
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

    @Environment(ThemeManager.self) private var theme

    private var netBalance: Double { report.totalIncome - report.totalExpenses }
    private var netColor: Color { netBalance >= 0 ? AppColors.income : AppColors.expense }

    var body: some View {
        HStack(spacing: 12) {
            SummaryStatCard(
                label: "Income",
                value: report.totalIncome.maskedCurrency(hidden: theme.hideAmounts),
                color: AppColors.income
            )
            SummaryStatCard(
                label: "Expenses",
                value: report.totalExpenses.maskedCurrency(hidden: theme.hideAmounts),
                color: AppColors.expense
            )
            SummaryStatCard(
                label: "Net",
                value: netBalance.maskedCurrency(hidden: theme.hideAmounts),
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

// MARK: - Category Filter Bar

private struct CategoryFilterBar: View {
    let categories: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterPill(title: "All", isSelected: selected == nil) {
                    selected = nil
                }
                ForEach(categories, id: \.self) { category in
                    FilterPill(title: category, isSelected: selected == category) {
                        selected = selected == category ? nil : category
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

private struct FilterPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color.accentColor : AppColors.surface)
                .foregroundStyle(isSelected ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

// MARK: - Transaction Section

private struct TransactionSection: View {
    let transactions: [Transaction]
    let isLocked: Bool
    let onAdd: () -> Void
    let onEdit: (Transaction) -> Void
    let onDeleteRequest: (Transaction) -> Void

    @Environment(ThemeManager.self) private var theme
    @State private var selectedCategory: String? = nil

    private var categories: [String] {
        let present = Set(transactions.map(\.category))
        let ordered = orderedCategories.filter { present.contains($0) }
        let remainder = present.subtracting(orderedCategories).sorted()
        return ordered + remainder
    }

    private var filtered: [Transaction] {
        let sorted = transactions.sorted { $0.dateAsDate > $1.dateAsDate }
        guard let cat = selectedCategory else { return sorted }
        return sorted.filter { $0.category == cat }
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(transactions.isEmpty ? "Transactions" : "Transactions (\(filtered.count))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !transactions.isEmpty, selectedCategory != nil {
                    let filteredNet = filtered.reduce(0.0) { sum, t in
                        t.type == .income ? sum + t.amount : sum - t.amount
                    }
                    Text("\(filteredNet >= 0 ? "+" : "")\(filteredNet.maskedCurrency(hidden: theme.hideAmounts))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(filteredNet >= 0 ? AppColors.income : AppColors.expense)
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
                if categories.count > 1 {
                    CategoryFilterBar(categories: categories, selected: $selectedCategory)
                }
                if filtered.isEmpty {
                    CardContainer {
                        Text("No transactions in this category")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    }
                } else {
                    CardContainer {
                        VStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, transaction in
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
}

private struct TransactionRow: View {
    let transaction: Transaction
    let isLocked: Bool
    let onEdit: () -> Void
    let onDeleteRequest: () -> Void

    @Environment(ThemeManager.self) private var theme

    private var amountColor: Color { transaction.type == .income ? AppColors.income : AppColors.expense }
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
            Text("\(amountSign)\(transaction.amount.maskedCurrency(hidden: theme.hideAmounts))")
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

// MARK: - Transaction Form Helpers

extension TransactionFormSheet {
    @ViewBuilder
    func typeToggleButton(_ t: TransactionType, label: String) -> some View {
        let color = t == .income ? AppColors.income : AppColors.expense
        let isSelected = type == t
        Button {
            type = t
            category = ""
        } label: {
            Text(label)
                .font(.subheadline.weight(isSelected ? .semibold : .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isSelected ? color : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .foregroundStyle(isSelected ? Color.white : color)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Form Helpers

private struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
            content()
        }
    }
}

private extension View {
    func styledInput() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.border, lineWidth: 1))
    }
}

// MARK: - Share Report Sheet

private struct ShareReportSheet: View {
    let reportStub: Report
    let viewModel: ReportDetailViewModel
    var onLeft: (() -> Void)? = nil

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var selectedRole: ReportRole = .viewer
    @State private var isSharing = false
    @State private var isLeaving = false
    @State private var error: String?

    private var liveReport: Report { viewModel.report ?? reportStub }
    private var members: [ReportMember] { liveReport.members ?? [] }
    private var isOwner: Bool { liveReport.isOwner }
    private var currentUserEmail: String? { auth.email }
    private var trimmedEmail: String { email.trimmingCharacters(in: .whitespaces) }
    private var isEmailValid: Bool { trimmedEmail.contains("@") }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if isOwner {
                        shareForm
                    }
                    membersList
                }
                .padding(20)
            }
            .background(AppColors.bgApp)
            .navigationTitle(isOwner ? "Share Report" : "Report Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isOwner {
                    Button(role: .destructive) {
                        Task { await leaveReport() }
                    } label: {
                        Group {
                            if isLeaving {
                                ProgressView()
                            } else {
                                Text("Leave Report")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .background(AppColors.surface)
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(AppColors.border), alignment: .top)
                }
            }
        }
    }

    // MARK: - Share form (owner only)

    private var shareForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Invite by email")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                TextField("name@example.com", text: $email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .styledInput()

                Menu {
                    Picker("Role", selection: $selectedRole) {
                        Text("Can view").tag(ReportRole.viewer)
                        Text("Can edit").tag(ReportRole.editor)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedRole == .viewer ? "Can view" : "Can edit")
                            .font(.subheadline)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.border, lineWidth: 1))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)

                Button {
                    Task { await share() }
                } label: {
                    Group {
                        if isSharing {
                            ProgressView()
                        } else {
                            Text("Share")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(width: 58)
                    .padding(.vertical, 10)
                    .background(isEmailValid ? Color.accentColor : AppColors.surfaceMuted)
                    .foregroundStyle(isEmailValid ? .white : AppColors.textTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .disabled(!isEmailValid || isSharing)
            }

            if let error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Divider()
        }
    }

    // MARK: - Members list

    private var membersList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Members")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)

            if members.isEmpty {
                CardContainer {
                    Text("No members yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            } else {
                CardContainer {
                    VStack(spacing: 0) {
                        ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                            if index > 0 { Divider() }
                            MemberRow(
                                member: member,
                                isCurrentUser: member.email == currentUserEmail,
                                isOwnerView: isOwner,
                                onUpdateRole: { role in
                                    Task { await updateRole(shareId: member.id, role: role) }
                                },
                                onRemove: {
                                    Task { await removeMember(shareId: member.id) }
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func share() async {
        guard let token = auth.token else { return }
        isSharing = true
        error = nil
        defer { isSharing = false }
        do {
            try await viewModel.shareReport(reportId: reportStub.id, email: trimmedEmail, role: selectedRole, token: token)
            email = ""
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func updateRole(shareId: String, role: ReportRole) async {
        guard let token = auth.token else { return }
        do {
            try await viewModel.updateMemberRole(shareId: shareId, role: role, token: token)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func removeMember(shareId: String) async {
        guard let token = auth.token else { return }
        do {
            try await viewModel.unshareReport(shareId: shareId, token: token)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func leaveReport() async {
        guard let token = auth.token else { return }
        isLeaving = true
        defer { isLeaving = false }
        do {
            try await viewModel.leaveSharedReport(reportId: reportStub.id, token: token)
            dismiss()
            onLeft?()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Member Row

private struct MemberRow: View {
    let member: ReportMember
    let isCurrentUser: Bool
    let isOwnerView: Bool
    let onUpdateRole: (ReportRole) -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            memberAvatar

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(member.displayName)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    if isCurrentUser {
                        Text("(You)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                if member.fullName != nil {
                    Text(member.email)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isOwnerView && member.role != .owner {
                HStack(spacing: 2) {
                    Menu {
                        Picker("Role", selection: Binding(
                            get: { member.role },
                            set: { onUpdateRole($0) }
                        )) {
                            Text("Can view").tag(ReportRole.viewer)
                            Text("Can edit").tag(ReportRole.editor)
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(member.role.label)
                                .font(.caption)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(AppColors.surfaceMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)

                    Button(action: onRemove) {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Text(member.role.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var memberAvatar: some View {
        ZStack {
            Circle()
                .fill(Color.accentColor.opacity(0.12))
                .frame(width: 36, height: 36)
            Text(member.initials)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
        }
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
