import SwiftUI

/// Reusable card wrapper used throughout the app.
struct CardContainer<Content: View>: View {
    var verticalPadding: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal)
            .padding(.vertical, verticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.surface)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
