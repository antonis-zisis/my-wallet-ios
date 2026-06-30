import SwiftUI

// MARK: - Billing badge

private struct BillingBadge: View {
    let billingCycle: BillingCycle

    var body: some View {
        Text(billingCycle.label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12))
            .foregroundStyle(.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct CategoryBadge: View {
    let category: String

    private var color: Color {
        CategoryColors.subscription[category] ?? CategoryColors.fallback
    }

    var body: some View {
        Text(category)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct CancelledBadge: View {
    var body: some View {
        Text("Cancelled")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(AppColors.expense.opacity(0.15))
            .foregroundStyle(AppColors.expense)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

private struct TrialBadge: View {
    var body: some View {
        Text("Trial")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.15))
            .foregroundStyle(Color.orange)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Subscription row

private struct SubscriptionRow: View {
    let subscription: Subscription

    @Environment(ThemeManager.self) private var theme

    /// Relative countdown to the next renewal, shown only within the next 30
    /// days (mirrors the web row).
    private var renewalRelativeLabel: String? {
        switch subscription.daysUntilNextRenewal {
        case ..<0:  return nil
        case 0:     return "today"
        case 1:     return "tomorrow"
        case ..<30: return "in \(subscription.daysUntilNextRenewal)d"
        default:    return nil
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            SubscriptionAvatar(subscription: subscription)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    BillingBadge(billingCycle: subscription.billingCycle)
                    if let category = subscription.category, !category.isEmpty {
                        CategoryBadge(category: category)
                    }
                    if subscription.isInTrial { TrialBadge() }
                    if subscription.isCancelled { CancelledBadge() }
                }

                HStack(spacing: 6) {
                    Text(subscription.amount.maskedCurrency(hidden: theme.hideAmounts))
                    if subscription.billingCycle != .monthly {
                        Text("·")
                        Text("≈ \(subscription.monthlyCost.maskedCurrency(hidden: theme.hideAmounts))/mo")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if subscription.isActive {
                    Group {
                        if subscription.isInTrial,
                           let days = subscription.trialDaysRemaining,
                           let endDate = subscription.formattedTrialEndDate {
                            switch days {
                            case 0:
                                Text("trial ends today · \(Text(endDate).fontWeight(.semibold))")
                            case 1:
                                Text("trial ends tomorrow · \(Text(endDate).fontWeight(.semibold))")
                            default:
                                Text("trial ends in \(days) days · \(Text(endDate).fontWeight(.semibold))")
                            }
                        } else if subscription.isCancelled, let endDate = subscription.formattedEndDate {
                            Text("active until \(Text(endDate).fontWeight(.semibold))")
                        } else if let relative = renewalRelativeLabel {
                            Text("next renewal at \(Text(subscription.formattedNextRenewalDate).fontWeight(.semibold)) · \(relative)")
                        } else {
                            Text("next renewal at \(Text(subscription.formattedNextRenewalDate).fontWeight(.semibold))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                if let detail = subscription.detailLine {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Sort menu

private struct SubscriptionSortMenu: View {
    @Bindable var viewModel: SubscriptionsViewModel

    var body: some View {
        Menu {
            Picker("Sort", selection: $viewModel.sortOption) {
                ForEach(SubscriptionSortOption.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))
        }
    }
}

// MARK: - Info popover

private struct InfoPopover: View {
    let message: String
    @State private var isShowing = false

    var body: some View {
        Button {
            isShowing.toggle()
        } label: {
            Image(systemName: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isShowing) {
            Text(message)
                .font(.subheadline)
                .padding(12)
                .presentationCompactAdaptation(.popover)
        }
    }
}

// MARK: - Cost summary

private struct CostSummaryCards: View {
    let monthlyCost: Double
    let yearlyCost: Double
    let thisMonthCost: Double

    @Environment(ThemeManager.self) private var theme

    private var currentMonthName: String {
        Date().formatted(.dateTime.month(.wide))
    }

    var body: some View {
        HStack(spacing: 8) {
            CardContainer(verticalPadding: 10, expandHeight: true) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(monthlyCost.maskedCurrency(hidden: theme.hideAmounts))
                        .font(.title2.bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            CardContainer(verticalPadding: 10, expandHeight: true) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yearly cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(yearlyCost.maskedCurrency(hidden: theme.hideAmounts))
                        .font(.title2.bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
            CardContainer(verticalPadding: 10, expandHeight: true) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text("This month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        InfoPopover(message: "Total charged in \(currentMonthName)")
                    }
                    Text(thisMonthCost.maskedCurrency(hidden: theme.hideAmounts))
                        .font(.title2.bold())
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Insight cards

private struct InsightCards: View {
    let nextRenewal: Subscription?
    let mostExpensive: Subscription?

    @Environment(ThemeManager.self) private var theme

    var body: some View {
        VStack(spacing: 8) {
            CardContainer(verticalPadding: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let sub = nextRenewal {
                        Text("Next renewal · \(sub.nextRenewalDate.formatted(Date.FormatStyle().month(.wide).day().year()))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Text(sub.name)
                                .font(.body.weight(.semibold))
                                .lineLimit(1)
                            Text("·")
                                .font(.body)
                                .foregroundStyle(.secondary)
                            Text(sub.amount.maskedCurrency(hidden: theme.hideAmounts))
                                .font(.body.weight(.semibold))
                                .lineLimit(1)
                        }
                        .minimumScaleFactor(0.8)
                    } else {
                        Text("Next renewal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("–")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }

            CardContainer(verticalPadding: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    if let sub = mostExpensive {
                        HStack(alignment: .top, spacing: 4) {
                            Text("Most expensive · \(sub.monthlyCost.maskedCurrency(hidden: theme.hideAmounts))/mo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            InfoPopover(message: "Yearly cost: \((sub.monthlyCost * 12).maskedCurrency(hidden: theme.hideAmounts))")
                        }
                        Text(sub.name)
                            .font(.body.weight(.semibold))
                            .lineLimit(1)
                    } else {
                        Text("Most expensive")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("–")
                            .font(.subheadline.weight(.semibold))
                    }
                }
            }
        }
    }
}

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

private struct SubscriptionFormSheet: View {
    enum Mode {
        case create
        case edit(Subscription)

        var title: String {
            switch self {
            case .create: return "New Subscription"
            case .edit:   return "Edit Subscription"
            }
        }
    }

    let mode: Mode
    let onSubmit: (CreateSubscriptionInput) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var amount: String
    @State private var billingCycle: BillingCycle
    @State private var startDate: Date
    @State private var category: SubscriptionCategory?
    @State private var isTrial: Bool
    @State private var trialEndsAt: Date
    @State private var url: String
    @State private var paymentMethod: String
    @State private var notes: String
    @State private var showAdditional: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    init(mode: Mode, onSubmit: @escaping (CreateSubscriptionInput) -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        let defaultTrialEnd = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
        switch mode {
        case .create:
            _name          = State(initialValue: "")
            _amount        = State(initialValue: "")
            _billingCycle  = State(initialValue: .monthly)
            _startDate     = State(initialValue: Date())
            _category      = State(initialValue: nil)
            _isTrial       = State(initialValue: false)
            _trialEndsAt   = State(initialValue: defaultTrialEnd)
            _url           = State(initialValue: "")
            _paymentMethod = State(initialValue: "")
            _notes         = State(initialValue: "")
            _showAdditional = State(initialValue: false)
        case .edit(let sub):
            _name         = State(initialValue: sub.name)
            _amount       = State(initialValue: String(format: "%.2f", sub.amount))
            _billingCycle = State(initialValue: sub.billingCycle)
            _startDate    = State(initialValue: Subscription.parseDate(sub.startDate))
            _category     = State(initialValue: sub.category.flatMap(SubscriptionCategory.init(rawValue:)))
            if let t = sub.trialEndsAt {
                _isTrial     = State(initialValue: sub.isInTrial)
                _trialEndsAt = State(initialValue: Subscription.parseDate(t))
            } else {
                _isTrial     = State(initialValue: false)
                _trialEndsAt = State(initialValue: defaultTrialEnd)
            }
            _url           = State(initialValue: sub.url ?? "")
            _paymentMethod = State(initialValue: sub.paymentMethod ?? "")
            _notes         = State(initialValue: sub.notes ?? "")
            _showAdditional = State(initialValue: !(sub.url ?? "").isEmpty || !(sub.paymentMethod ?? "").isEmpty || !(sub.notes ?? "").isEmpty)
        }
    }

    private var parsedAmount: Double? {
        Double(amount.replacingOccurrences(of: ",", with: "."))
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && (parsedAmount ?? -1) >= 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    fieldGroup(label: "Name") {
                        TextField("e.g. Netflix", text: $name)
                            .autocorrectionDisabled()
                            .styledInput()
                    }

                    fieldGroup(label: "Amount") {
                        TextField("9.99", text: $amount)
                            .keyboardType(.decimalPad)
                            .styledInput()
                    }

                    fieldGroup(label: "Billing Cycle") {
                        Picker("", selection: $billingCycle) {
                            ForEach(BillingCycle.allCases, id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledInput()
                    }

                    fieldGroup(label: "Start Date") {
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .styledInput()
                    }

                    fieldGroup(label: "Category") {
                        Picker("", selection: $category) {
                            Text("Uncategorized").tag(SubscriptionCategory?.none)
                            ForEach(SubscriptionCategory.allCases) { category in
                                Text(category.label).tag(SubscriptionCategory?.some(category))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledInput()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Currently on a free trial")
                                .font(.subheadline)
                            Spacer()
                            Toggle("", isOn: $isTrial.animation())
                                .labelsHidden()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColors.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(AppColors.border, lineWidth: 1))

                        if isTrial {
                            fieldGroup(label: "Trial ends") {
                                DatePicker("", selection: $trialEndsAt, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .styledInput()
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { showAdditional.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showAdditional ? "chevron.up" : "chevron.down")
                                    .font(.caption.weight(.medium))
                                Text("Additional details")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(.secondary)
                        }

                        if showAdditional {
                            VStack(spacing: 12) {
                                fieldGroup(label: "Website / Billing URL") {
                                    TextField("https://...", text: $url)
                                        .keyboardType(.URL)
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.never)
                                        .styledInput()
                                }
                                fieldGroup(label: "Payment method") {
                                    TextField("e.g. Revolut, Visa *1234", text: $paymentMethod)
                                        .styledInput()
                                }
                                fieldGroup(label: "Notes") {
                                    TextField("e.g. shared with sister", text: $notes)
                                        .styledInput()
                                }
                            }
                        }
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
                    Button(mode.title == "New Subscription" ? "Create" : "Save") {
                        let input = CreateSubscriptionInput(
                            name: name.trimmingCharacters(in: .whitespaces),
                            amount: parsedAmount ?? 0,
                            billingCycle: billingCycle.rawValue,
                            startDate: Self.dateFormatter.string(from: startDate),
                            trialEndsAt: isTrial ? Self.dateFormatter.string(from: trialEndsAt) : nil,
                            category: category?.rawValue,
                            notes: notes.isEmpty ? nil : notes,
                            paymentMethod: paymentMethod.isEmpty ? nil : paymentMethod,
                            url: url.isEmpty ? nil : url
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
    private func fieldGroup<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

// MARK: - Resume form

private struct ResumeFormSheet: View {
    let subscription: Subscription
    let onSubmit: (ResumeSubscriptionInput) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var amount: String
    @State private var billingCycle: BillingCycle
    @State private var startDate = Date()

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(subscription: Subscription, onSubmit: @escaping (ResumeSubscriptionInput) -> Void) {
        self.subscription = subscription
        self.onSubmit = onSubmit
        _amount = State(initialValue: String(format: "%.2f", subscription.amount))
        _billingCycle = State(initialValue: subscription.billingCycle)
    }

    private var parsedAmount: Double? { Double(amount.replacingOccurrences(of: ",", with: ".")) }

    private var isValid: Bool { (parsedAmount ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enter a new start date for **\(subscription.name)**. You can also update the amount and billing cycle.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Amount")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        TextField("9.99", text: $amount)
                            .keyboardType(.decimalPad)
                            .styledInput()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Billing Cycle")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        Picker("", selection: $billingCycle) {
                            ForEach(BillingCycle.allCases, id: \.self) {
                                Text($0.label).tag($0)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .styledInput()
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("New Start Date")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $startDate, displayedComponents: .date)
                            .datePickerStyle(.compact)
                            .labelsHidden()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .styledInput()
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Resume Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Resume") {
                        let input = ResumeSubscriptionInput(
                            id: subscription.id,
                            startDate: Self.dateFormatter.string(from: startDate),
                            amount: parsedAmount ?? subscription.amount,
                            billingCycle: billingCycle.rawValue
                        )
                        onSubmit(input)
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
        }
    }
}

// MARK: - Main View

struct SubscriptionsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = SubscriptionsViewModel()

    @State private var showCreate = false
    @State private var subscriptionToEdit: Subscription?
    @State private var subscriptionToCancel: Subscription?
    @State private var subscriptionToResume: Subscription?
    @State private var subscriptionToDelete: Subscription?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if !viewModel.activeSubscriptions.isEmpty {
                        VStack(spacing: 8) {
                            CostSummaryCards(
                                monthlyCost: viewModel.totalMonthlyCost,
                                yearlyCost: viewModel.totalYearlyCost,
                                thisMonthCost: viewModel.thisMonthCost
                            )
                            InsightCards(
                                nextRenewal: viewModel.nextRenewalSubscription,
                                mostExpensive: viewModel.mostExpensiveSubscription
                            )
                            if !viewModel.categoryBreakdown.isEmpty {
                                SubscriptionCategoryChart(breakdown: viewModel.categoryBreakdown)
                            }
                        }
                    }

                    activeSection
                    inactiveSection
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Subscriptions")
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
                    await viewModel.loadAll(token: token)
                }
            }
            .refreshable {
                if let token = auth.token {
                    await viewModel.loadAll(token: token)
                }
            }
        }
        .sheet(isPresented: $showCreate) {
            SubscriptionFormSheet(mode: .create) { input in
                guard let token = auth.token else { return }
                Task { await viewModel.create(input: input, token: token) }
            }
        }
        .sheet(item: $subscriptionToEdit) { sub in
            SubscriptionFormSheet(mode: .edit(sub)) { input in
                guard let token = auth.token else { return }
                let updateInput = UpdateSubscriptionInput(
                    id: sub.id,
                    name: input.name,
                    amount: input.amount,
                    billingCycle: input.billingCycle,
                    startDate: input.startDate,
                    trialEndsAt: input.trialEndsAt,
                    category: input.category,
                    notes: input.notes,
                    paymentMethod: input.paymentMethod,
                    url: input.url
                )
                Task { await viewModel.update(input: updateInput, token: token) }
            }
        }
        .sheet(item: $subscriptionToResume) { sub in
            ResumeFormSheet(subscription: sub) { input in
                guard let token = auth.token else { return }
                Task { await viewModel.resume(input: input, token: token) }
            }
        }
        .alert(
            "Cancel Subscription",
            isPresented: Binding(
                get: { subscriptionToCancel != nil },
                set: { if !$0 { subscriptionToCancel = nil } }
            ),
            presenting: subscriptionToCancel
        ) { sub in
            Button("Cancel Subscription", role: .destructive) {
                guard let token = auth.token else { return }
                Task { await viewModel.cancel(id: sub.id, token: token) }
            }
            Button("Dismiss", role: .cancel) {}
        } message: { sub in
            Text("Are you sure you want to cancel \"\(sub.name)\"? It will remain active until the end of the billing period.")
        }
        .alert(
            "Delete Subscription",
            isPresented: Binding(
                get: { subscriptionToDelete != nil },
                set: { if !$0 { subscriptionToDelete = nil } }
            ),
            presenting: subscriptionToDelete
        ) { sub in
            Button("Delete", role: .destructive) {
                guard let token = auth.token else { return }
                Task { await viewModel.delete(id: sub.id, token: token) }
            }
            Button("Cancel", role: .cancel) {}
        } message: { sub in
            Text("Are you sure you want to permanently delete \"\(sub.name)\"? This action cannot be undone.")
        }
    }

    // MARK: Active section

    @ViewBuilder
    private var activeSection: some View {
        if viewModel.isLoadingActive {
            loadingList
        } else if viewModel.activeError {
            Text("Failed to load subscriptions.")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
        } else if viewModel.activeSubscriptions.isEmpty {
            emptyActiveState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Active (\(viewModel.activeSubscriptions.count))")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    SubscriptionSortMenu(viewModel: viewModel)
                }
                .padding(.top, 8)
                CardContainer(verticalPadding: 6) {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.sortedActiveSubscriptions.enumerated()), id: \.element.id) { index, sub in
                        HStack(spacing: 0) {
                            SubscriptionRow(subscription: sub)
                            Menu {
                                Button("Edit") { subscriptionToEdit = sub }
                                if !sub.isCancelled {
                                    Button("Cancel Subscription", role: .destructive) {
                                        subscriptionToCancel = sub
                                    }
                                } else {
                                    Button("Resume") { subscriptionToResume = sub }
                                }
                                Divider()
                                Button("Delete", role: .destructive) { subscriptionToDelete = sub }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 12)
                            }
                        }
                        if index < viewModel.sortedActiveSubscriptions.count - 1 {
                            Divider()
                        }
                    }
                }
            }
            }
        }
    }

    // MARK: Inactive section

    @ViewBuilder
    private var inactiveSection: some View {
        if !viewModel.inactiveSubscriptions.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showInactive.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.showInactive ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.medium))
                        Text("Inactive Subscriptions (\(viewModel.inactiveSubscriptions.count))")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }

                if viewModel.showInactive {
                    if viewModel.inactiveError {
                        Text("Failed to load inactive subscriptions.")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    } else {
                        CardContainer(verticalPadding: 6) {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.inactiveSubscriptions.enumerated()), id: \.element.id) { index, sub in
                                    HStack(spacing: 0) {
                                        SubscriptionRow(subscription: sub)
                                        Menu {
                                            Button("Resume") { subscriptionToResume = sub }
                                            Divider()
                                            Button("Delete", role: .destructive) { subscriptionToDelete = sub }
                                        } label: {
                                            Image(systemName: "ellipsis")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                                .padding(.leading, 12)
                                        }
                                    }
                                    if index < viewModel.inactiveSubscriptions.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Loading placeholder

    private var loadingList: some View {
        VStack(spacing: 8) {
            // Summary cards row
            HStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { _ in
                    CardContainer(verticalPadding: 10, expandHeight: true) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Monthly cost")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                            Text("€000.00")
                                .font(.title2.bold())
                                .redacted(reason: .placeholder)
                        }
                    }
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            // Insight cards
            ForEach(0..<2, id: \.self) { _ in
                CardContainer(verticalPadding: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Next renewal · May 20, 2026")
                            .font(.caption)
                            .redacted(reason: .placeholder)
                        HStack(spacing: 4) {
                            Text("Subscription name")
                                .font(.body.weight(.semibold))
                                .redacted(reason: .placeholder)
                            Text("·")
                                .font(.body)
                            Text("€00.00")
                                .font(.body.weight(.semibold))
                                .redacted(reason: .placeholder)
                        }
                    }
                }
            }

            // Active section label + list
            Text("Active (–)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .redacted(reason: .placeholder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            CardContainer(verticalPadding: 6) {
                VStack(spacing: 0) {
                    ForEach(0..<5, id: \.self) { index in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(.secondary.opacity(0.15))
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("Subscription name")
                                        .font(.subheadline.weight(.medium))
                                        .redacted(reason: .placeholder)
                                    Text("Monthly")
                                        .font(.caption2.weight(.semibold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.secondary.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                        .redacted(reason: .placeholder)
                                }
                                Text("€9.99 · €119.88/yr")
                                    .font(.caption)
                                    .redacted(reason: .placeholder)
                                Text("next renewal at Jan 1, 2025")
                                    .font(.caption)
                                    .redacted(reason: .placeholder)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.3))
                                .padding(.leading, 12)
                        }
                        .padding(.vertical, 10)
                        if index < 4 { Divider() }
                    }
                }
            }
        }
    }

    // MARK: Empty state

    private var emptyActiveState: some View {
        VStack(spacing: 12) {
            Image(systemName: "creditcard")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No active subscriptions yet.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Button("Add your first subscription") {
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
}

#Preview {
    SubscriptionsView()
        .environment(AuthViewModel())
}
