import SwiftUI

// MARK: - Billing badge

private struct BillingBadge: View {
    let billingCycle: BillingCycle

    var body: some View {
        Text(billingCycle == .monthly ? "Monthly" : "Yearly")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(billingCycle == .monthly ? AppColors.income.opacity(0.15) : AppColors.brand.opacity(0.15))
            .foregroundStyle(billingCycle == .monthly ? AppColors.income : AppColors.brand)
            .clipShape(Capsule())
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
            .clipShape(Capsule())
    }
}

// MARK: - Subscription row

private struct SubscriptionRow: View {
    let subscription: Subscription

    var amountText: String {
        String(format: "€%.2f", subscription.amount)
    }

    var equivalentText: String {
        if subscription.billingCycle == .yearly {
            return String(format: "€%.2f/mo", subscription.monthlyCost)
        } else {
            return String(format: "€%.2f/yr", subscription.amount * 12)
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(subscription.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    BillingBadge(billingCycle: subscription.billingCycle)

                    if subscription.isCancelled {
                        CancelledBadge()
                    }
                }

                if subscription.isActive {
                    Group {
                        if subscription.isCancelled, let endDate = subscription.formattedEndDate {
                            Text("active until \(Text(endDate).fontWeight(.semibold))")
                        } else {
                            Text("next renewal at \(Text(subscription.formattedNextRenewalDate).fontWeight(.semibold))")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(amountText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(equivalentText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: - Cost summary

private struct CostSummaryCards: View {
    let monthlyCost: Double
    let yearlyCost: Double

    var body: some View {
        HStack(spacing: 12) {
            CardContainer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Monthly cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "€%.2f", monthlyCost))
                        .font(.title2.bold())
                }
            }
            CardContainer {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yearly cost")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(String(format: "€%.2f", yearlyCost))
                        .font(.title2.bold())
                }
            }
        }
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
            case .edit: return "Edit Subscription"
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

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(mode: Mode, onSubmit: @escaping (CreateSubscriptionInput) -> Void) {
        self.mode = mode
        self.onSubmit = onSubmit
        switch mode {
        case .create:
            _name = State(initialValue: "")
            _amount = State(initialValue: "")
            _billingCycle = State(initialValue: .monthly)
            _startDate = State(initialValue: Date())
        case .edit(let sub):
            _name = State(initialValue: sub.name)
            _amount = State(initialValue: String(format: "%.2f", sub.amount))
            _billingCycle = State(initialValue: sub.billingCycle)
            let parsed = Self.dateFormatter.date(from: sub.startDate) ?? Date()
            _startDate = State(initialValue: parsed)
        }
    }

    private var parsedAmount: Double? { Double(amount.replacingOccurrences(of: ",", with: ".")) }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        (parsedAmount ?? 0) > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. Netflix", text: $name)
                        .autocorrectionDisabled()
                }
                header: { Text("Name") }

                Section {
                    TextField("9.99", text: $amount)
                        .keyboardType(.decimalPad)
                }
                header: { Text("Amount") }

                Section {
                    Picker("Billing Cycle", selection: $billingCycle) {
                        Text("Monthly").tag(BillingCycle.monthly)
                        Text("Yearly").tag(BillingCycle.yearly)
                    }
                    .pickerStyle(.segmented)
                }
                header: { Text("Billing Cycle") }

                Section {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                header: { Text("Start Date") }
            }
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
                            startDate: Self.dateFormatter.string(from: startDate)
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
            Form {
                Section {
                    Text("Enter a new start date for **\(subscription.name)**. You can also update the amount and billing cycle.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    TextField("9.99", text: $amount)
                        .keyboardType(.decimalPad)
                }
                header: { Text("Amount") }

                Section {
                    Picker("Billing Cycle", selection: $billingCycle) {
                        Text("Monthly").tag(BillingCycle.monthly)
                        Text("Yearly").tag(BillingCycle.yearly)
                    }
                    .pickerStyle(.segmented)
                }
                header: { Text("Billing Cycle") }

                Section {
                    DatePicker("New Start Date", selection: $startDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                header: { Text("New Start Date") }
            }
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
                        CostSummaryCards(
                            monthlyCost: viewModel.totalMonthlyCost,
                            yearlyCost: viewModel.totalYearlyCost
                        )
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
                    startDate: input.startDate
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
            CardContainer {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.activeSubscriptions.enumerated()), id: \.element.id) { index, sub in
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
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .padding(.leading, 12)
                            }
                        }
                        if index < viewModel.activeSubscriptions.count - 1 {
                            Divider()
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
                        CardContainer {
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
        CardContainer {
            VStack(spacing: 0) {
                ForEach(0..<4, id: \.self) { index in
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Subscription name")
                                .font(.subheadline)
                                .redacted(reason: .placeholder)
                            Text("next renewal at Jan 1, 2025")
                                .font(.caption)
                                .redacted(reason: .placeholder)
                        }
                        Spacer()
                        Text("€99.99")
                            .font(.subheadline)
                            .redacted(reason: .placeholder)
                    }
                    .padding(.vertical, 10)
                    if index < 3 { Divider() }
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
