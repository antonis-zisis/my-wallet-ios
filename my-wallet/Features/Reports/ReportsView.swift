import SwiftUI

struct ReportsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = ReportsViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if viewModel.isLoading {
                        Text("00 reports")
                            .font(.subheadline)
                            .redacted(reason: .placeholder)
                            .padding(.horizontal, 4)
                        skeletonSection
                    } else {
                        if !viewModel.items.isEmpty {
                            Text("\(viewModel.totalCount) \(viewModel.totalCount == 1 ? "report" : "reports")")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                                .padding(.horizontal, 4)
                            reportSection
                        } else if viewModel.error == nil {
                            emptyState
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .background(AppColors.bgApp)
            .refreshable {
                guard let token = auth.token else { return }
                await viewModel.loadInitial(token: token)
            }
            .overlay { overlayContent }
            .navigationTitle("Reports")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreateSheet = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateReportSheet(viewModel: viewModel)
            }
            .task {
                // Run on first appear, and also re-run if a previous attempt errored
                guard (viewModel.items.isEmpty || viewModel.error != nil),
                      let token = auth.token else { return }
                await viewModel.loadInitial(token: token)
            }
        }
    }

    // MARK: - List content

    private var reportSection: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.items) { report in
                if report.id != viewModel.items.first?.id {
                    Divider()
                        .padding(.leading, 16)
                }
                NavigationLink {
                    ReportDetailView(stub: report) { updated in
                        viewModel.update(report: updated)
                    } onDelete: {
                        viewModel.remove(id: report.id)
                    }
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        ReportRow(report: report)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.textTertiary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .onAppear {
                    if report.id == viewModel.items.last?.id {
                        Task {
                            guard let token = auth.token else { return }
                            await viewModel.loadMore(token: token)
                        }
                    }
                }
            }

            if viewModel.isLoadingMore {
                Divider()
                HStack {
                    Spacer()
                    ProgressView()
                        .padding(.vertical, 8)
                    Spacer()
                }
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }

    private var skeletonSection: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { i in
                if i > 0 { Divider().padding(.leading, 16) }
                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Report title placeholder")
                            .font(.body)
                            .redacted(reason: .placeholder)
                        Text("12 transactions · 2 hours ago")
                            .font(.caption)
                            .redacted(reason: .placeholder)
                    }
                    Spacer()
                    Text("+€0,000.00")
                        .font(.subheadline.weight(.medium))
                        .redacted(reason: .placeholder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(AppColors.border, lineWidth: 1)
        )
    }

    // MARK: - Empty / error overlay

    @ViewBuilder
    private var overlayContent: some View {
        if !viewModel.isLoading, viewModel.error != nil {
            ContentUnavailableView(
                "Failed to load",
                systemImage: "exclamationmark.triangle",
                description: Text("Pull down to try again.")
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No reports yet.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Button("Create your first report") {
                showCreateSheet = true
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

// MARK: - Report Row

private struct ReportRow: View {
    let report: Report

    @Environment(ThemeManager.self) private var theme

    private var subtitle: String {
        var parts: [String] = []
        if let count = report.transactionCount {
            parts.append("\(count) \(count == 1 ? "transaction" : "transactions")")
        }
        parts.append(report.smartUpdatedAt)
        return parts.joined(separator: " · ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(report.title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            if let balance = report.netBalance {
                let positive = balance >= 0
                Text("\(positive ? "+" : "")\(balance.maskedCurrency(hidden: theme.hideAmounts))")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(positive ? AppColors.income : AppColors.expense)
            }
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .opacity(report.isLocked ? 1 : 0)
        }
    }
}

// MARK: - Create Report Sheet

private struct CreateReportSheet: View {
    let viewModel: ReportsViewModel

    @Environment(AuthViewModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var isSubmitting = false
    @State private var error: String?

    private let minLength = 3
    private let maxLength = 100

    private var trimmed: String { title.trimmingCharacters(in: .whitespaces) }
    private var isValid: Bool { trimmed.count >= minLength && trimmed.count <= maxLength }

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Report Title")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                TextField("e.g. January 2025", text: $title)
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
            .navigationTitle("New Report")
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
                            Button("Create") {
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
        guard isValid, let token = auth.token else { return }
        isSubmitting = true
        error = nil
        defer { isSubmitting = false }

        do {
            try await viewModel.createReport(title: trimmed, token: token)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// MARK: - Preview

#Preview {
    ReportsView()
        .environment(AuthViewModel())
}
