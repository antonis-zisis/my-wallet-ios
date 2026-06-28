import SwiftUI

struct CategoryBreakdownSlice: Identifiable {
    let category: String
    let total: Double
    var id: String { category }
}

// MARK: - Flow layout for the wrapping legend

private struct FlowLayout: Layout {
    var horizontalSpacing: CGFloat = 12
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var totalWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + verticalSpacing
                totalWidth = max(totalWidth, rowWidth - horizontalSpacing)
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        totalWidth = max(totalWidth, rowWidth - horizontalSpacing)
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + verticalSpacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Info popover

private struct ChartInfoPopover: View {
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

// MARK: - Spending by category chart

struct SubscriptionCategoryChart: View {
    let breakdown: [CategoryBreakdownSlice]

    @Environment(ThemeManager.self) private var theme
    @State private var isExpanded = false

    private var total: Double { breakdown.reduce(0) { $0 + $1.total } }

    private func color(for category: String) -> Color {
        CategoryColors.subscription[category] ?? CategoryColors.fallback
    }

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Text("Spending by category")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)

                    ChartInfoPopover(message: "Every amount is a monthly equivalent. Yearly and other billing cycles are spread evenly across the year, so each category reflects its true monthly share.")

                    Spacer()

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 180 : 0))
                    }
                    .buttonStyle(.plain)
                }

                if isExpanded {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(breakdown) { slice in
                                color(for: slice.category)
                                    .frame(width: total > 0 ? geo.size.width * (slice.total / total) : 0)
                            }
                        }
                    }
                    .frame(height: 10)
                    .clipShape(Capsule())

                    FlowLayout {
                        ForEach(breakdown) { slice in
                            let pct = total > 0 ? slice.total / total * 100 : 0
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(color(for: slice.category))
                                    .frame(width: 8, height: 8)
                                Text(slice.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(slice.total.maskedCurrency(hidden: theme.hideAmounts))
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text(String(format: "(%.1f%%)", pct))
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
        }
    }
}
