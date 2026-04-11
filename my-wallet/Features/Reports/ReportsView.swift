import SwiftUI

struct ReportsView: View {
    @Environment(AuthViewModel.self) private var auth
    @State private var viewModel = ReportsViewModel()
    @State private var showCreateSheet = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    if viewModel.isLoading {
                        skeletonSection
                    } else if !viewModel.items.isEmpty {
                        reportSection
                    } else if viewModel.error == nil {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
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
                    HStack {
                        ReportRow(report: report)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
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
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private var skeletonSection: some View {
        VStack(spacing: 0) {
            ForEach(0..<12, id: \.self) { i in
                if i > 0 { Divider().padding(.leading, 16) }
                HStack {
                    Text("Report title placeholder")
                        .redacted(reason: .placeholder)
                    Spacer()
                    Text("Just now")
                        .font(.caption)
                        .redacted(reason: .placeholder)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 4))
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
                .foregroundStyle(Color.secondary.opacity(0.3))
        )
    }
}

// MARK: - Report Row

private struct ReportRow: View {
    let report: Report

    var body: some View {
        HStack(spacing: 8) {
            Text(report.title)
                .font(.body)
                .foregroundStyle(.primary)
            Spacer()
            if report.isLocked {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Text(report.relativeUpdatedAt)
                .font(.caption)
                .foregroundStyle(.secondary)
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

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("e.g. January 2025", text: $title)
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
