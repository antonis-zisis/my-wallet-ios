import SwiftUI

// MARK: - Badges

private struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct ExpiredBadge: View {
    var body: some View {
        Text("Expired")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.expense.opacity(0.15))
            .foregroundStyle(AppColors.expense)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct ExpiringSoonBadge: View {
    var body: some View {
        Text("Expiring soon")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundStyle(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Contract row

private struct ContractRow: View {
    let contract: Contract

    @Environment(ThemeManager.self) private var theme

    private var expiryText: Text {
        guard let endDate = contract.formattedEndDate else {
            return Text("Open-ended")
        }
        var line = Text("expires ") + Text(endDate).fontWeight(.semibold)
        if let days = contract.daysUntilExpiration {
            let relative: String
            switch days {
            case ..<0: relative = "expired"
            case 0:    relative = "today"
            case 1:    relative = "tomorrow"
            default:   relative = "in \(days)d"
            }
            line = line + Text(" · \(relative)")
        }
        return line
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(contract.provider)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    CategoryBadge(category: contract.category)
                    if contract.isExpired {
                        ExpiredBadge()
                    } else if contract.isExpiringSoon {
                        ExpiringSoonBadge()
                    }
                }

                if let plan = contract.plan, !plan.isEmpty {
                    Text(plan)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                expiryText
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            if let cost = contract.cost {
                Text(cost.maskedCurrency(hidden: theme.hideAmounts))
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 10)
        .opacity(contract.isExpired ? 0.6 : 1)
    }
}

// MARK: - Styled input helper

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

// MARK: - Create / Edit form

private struct ContractFormSheet: View {
    enum Mode {
        case create
        case edit(Contract)

        var title: String {
            switch self {
            case .create: return "New Contract"
            case .edit:   return "Edit Contract"
            }
        }
    }

    let mode: Mode
    let onSubmit: (CreateContractInput) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var provider: String
    @State private var category: ContractCategory?
    @State private var customCategory: String
    @State private var plan: String
    @State private var cost: String
    @State private var startDate: Date?
    @State private var endDate: Date?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    init(mode: Mode, onSubmit: @escaping (CreateContractInput) -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        switch mode {
        case .create:
            _provider       = State(initialValue: "")
            _category       = State(initialValue: nil)
            _customCategory = State(initialValue: "")
            _plan           = State(initialValue: "")
            _cost           = State(initialValue: "")
            _startDate      = State(initialValue: nil)
            _endDate        = State(initialValue: nil)
        case .edit(let contract):
            _provider = State(initialValue: contract.provider)
            let known = ContractCategory(rawValue: contract.category)
            _category = State(initialValue: known ?? .other)
            _customCategory = State(initialValue: known == nil ? contract.category : "")
            _plan = State(initialValue: contract.plan ?? "")
            _cost = State(initialValue: contract.cost.map { String(format: "%.2f", $0) } ?? "")
            _startDate = State(initialValue: contract.startDate.map(Contract.parseDate))
            _endDate   = State(initialValue: contract.endDate.map(Contract.parseDate))
        }
    }

    private var resolvedCategory: String {
        if category == .other {
            let trimmed = customCategory.trimmingCharacters(in: .whitespaces)
            return trimmed.isEmpty ? "Other" : trimmed
        }
        return category?.rawValue ?? ""
    }

    private var parsedCost: Double? {
        let trimmed = cost.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed.replacingOccurrences(of: ",", with: "."))
    }

    private var datesOrdered: Bool {
        guard let startDate, let endDate else { return true }
        return endDate >= startDate
    }

    private var isValid: Bool {
        let hasProvider = !provider.trimmingCharacters(in: .whitespaces).isEmpty
        let hasCategory = category != nil &&
            (category != .other || !customCategory.trimmingCharacters(in: .whitespaces).isEmpty)
        return hasProvider && hasCategory && datesOrdered
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    fieldGroup(label: "Provider") {
                        TextField("e.g. DEI", text: $provider)
                            .autocorrectionDisabled()
                            .styledInput()
                    }

                    fieldGroup(label: "Category") {
                        Picker("", selection: $category) {
                            Text("Select a category").tag(ContractCategory?.none)
                            ForEach(ContractCategory.allCases) { category in
                                Text(category.label).tag(ContractCategory?.some(category))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledInput()
                    }

                    if category == .other {
                        fieldGroup(label: "Custom category") {
                            TextField("e.g. Gym membership", text: $customCategory)
                                .styledInput()
                        }
                    }

                    fieldGroup(label: "Plan") {
                        TextField("e.g. MyHome Online", text: $plan)
                            .styledInput()
                    }

                    dateField(label: "Start Date (optional)", date: $startDate)
                    dateField(label: "End Date (optional)", date: $endDate)

                    fieldGroup(label: "Cost (optional)") {
                        TextField("e.g. 29.90", text: $cost)
                            .keyboardType(.decimalPad)
                            .styledInput()
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isCreate ? "Create" : "Save") {
                        let input = CreateContractInput(
                            category: resolvedCategory,
                            provider: provider.trimmingCharacters(in: .whitespaces),
                            plan: plan.trimmingCharacters(in: .whitespaces).isEmpty ? nil
                                : plan.trimmingCharacters(in: .whitespaces),
                            startDate: startDate.map(Self.dateFormatter.string(from:)),
                            endDate: endDate.map(Self.dateFormatter.string(from:)),
                            cost: parsedCost
                        )
                        onSubmit(input)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }

    private var isCreate: Bool {
        if case .create = mode { return true }
        return false
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

    @ViewBuilder
    private func dateField(label: String, date: Binding<Date?>) -> some View {
        fieldGroup(label: label) {
            if let value = date.wrappedValue {
                HStack {
                    DatePicker(
                        "",
                        selection: Binding(get: { value }, set: { date.wrappedValue = $0 }),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    Spacer()
                    Button {
                        date.wrappedValue = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .styledInput()
            } else {
                Button {
                    date.wrappedValue = Date()
                } label: {
                    HStack {
                        Text("Add date")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .styledInput()
            }
        }
    }
}

// MARK: - Main View

struct ContractsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = ContractsViewModel()

    @State private var showCreate = false
    @State private var contractToEdit: Contract?
    @State private var contractToDelete: Contract?

    private var showsToolbarControls: Bool {
        viewModel.isLoading || (!viewModel.error && (!viewModel.contracts.isEmpty || !viewModel.searchText.isEmpty))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    if showsToolbarControls {
                        controls
                    }
                    content
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Contracts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if let token = auth.token {
                    await viewModel.load(token: token)
                }
            }
            .refreshable {
                if let token = auth.token {
                    await viewModel.load(token: token)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            ContractFormSheet(mode: .create) { input in
                guard let token = auth.token else { return }
                Task { await viewModel.create(input: input, token: token) }
            }
        }
        .sheet(item: $contractToEdit) { contract in
            ContractFormSheet(mode: .edit(contract)) { input in
                guard let token = auth.token else { return }
                let updateInput = UpdateContractInput(
                    id: contract.id,
                    category: input.category,
                    provider: input.provider,
                    plan: input.plan,
                    startDate: input.startDate,
                    endDate: input.endDate,
                    cost: input.cost
                )
                Task { await viewModel.update(input: updateInput, token: token) }
            }
        }
        .alert(
            "Delete Contract",
            isPresented: Binding(
                get: { contractToDelete != nil },
                set: { if !$0 { contractToDelete = nil } }
            ),
            presenting: contractToDelete
        ) { contract in
            Button("Delete", role: .destructive) {
                guard let token = auth.token else { return }
                Task { await viewModel.delete(id: contract.id, token: token) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { contract in
            Text("Are you sure you want to permanently delete the contract with \"\(contract.provider)\"? This action cannot be undone.")
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Search by provider…", text: $viewModel.searchText)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))

            Menu {
                Picker("Sort", selection: $viewModel.sortBy) {
                    ForEach(ContractSortField.allCases) { field in
                        Text(field.label).tag(field)
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

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading {
            loadingList
        } else if viewModel.error {
            Text("Failed to load contracts.")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
        } else if viewModel.visibleContracts.isEmpty {
            if viewModel.searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyState
            } else {
                noMatchesState
            }
        } else {
            CardContainer(verticalPadding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.visibleContracts.enumerated()), id: \.element.id) { index, contract in
                        HStack(spacing: 0) {
                            ContractRow(contract: contract)
                            Menu {
                                Button("Edit") { contractToEdit = contract }
                                Divider()
                                Button("Delete", role: .destructive) { contractToDelete = contract }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 12)
                            }
                        }
                        if index < viewModel.visibleContracts.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No contracts yet.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Button("Add your first contract") {
                showCreate = true
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

    private var noMatchesState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No contracts match your search.")
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

    private var loadingList: some View {
        CardContainer(verticalPadding: 6) {
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Provider name")
                                .font(.subheadline.weight(.medium))
                                .redacted(reason: .placeholder)
                            Text("expires Jan 1, 2026 · in 30d")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                        }
                        Spacer()
                        Text("€00.00")
                            .font(.subheadline.weight(.semibold))
                            .redacted(reason: .placeholder)
                    }
                    .padding(.vertical, 10)
                    if index < 4 { Divider() }
                }
            }
        }
    }
}

#Preview {
    ContractsView()
        .environment(AuthViewModel())
        .environment(ThemeManager())
}
