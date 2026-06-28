import SwiftUI

// Mirrors web getSubscriptionLogoUrl: builds a logo.dev URL from the
// subscription's website, or returns nil to fall back to initials.
private func subscriptionLogoURL(urlString: String?, dark: Bool) -> URL? {
    let token = Config.logoDevToken
    guard !token.isEmpty,
          let urlString,
          let parsed = URL(string: urlString),
          let scheme = parsed.scheme?.lowercased(),
          scheme == "http" || scheme == "https",
          var host = parsed.host
    else {
        return nil
    }

    if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
    guard !host.isEmpty else { return nil }

    var components = URLComponents(string: "https://img.logo.dev/\(host)")
    components?.queryItems = [
        URLQueryItem(name: "token", value: token),
        URLQueryItem(name: "size", value: "128"),
        URLQueryItem(name: "format", value: "png"),
        URLQueryItem(name: "theme", value: dark ? "dark" : "light"),
    ]
    return components?.url
}

// Mirrors web getInitials.
private func initials(from name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    let parts = trimmed.split(whereSeparator: { $0.isWhitespace })
    if parts.count > 1, let first = parts.first?.first, let last = parts.last?.first {
        return "\(first)\(last)".uppercased()
    }
    return trimmed.isEmpty ? "" : String(trimmed.prefix(1)).uppercased()
}

struct SubscriptionAvatar: View {
    let subscription: Subscription

    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 32

    var body: some View {
        if let logoURL = subscriptionLogoURL(urlString: subscription.url, dark: colorScheme == .dark) {
            AsyncImage(url: logoURL) { phase in
                if case .success(let image) = phase {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    fallback
                }
            }
        } else {
            fallback
        }
    }

    private var fallback: some View {
        ZStack {
            Circle().fill(AppColors.brand)
            Text(initials(from: subscription.name))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}
