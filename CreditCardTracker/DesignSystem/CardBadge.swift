import SwiftUI

/// Rounded square with the issuer abbreviation ("CH", "AX", "C1"). When the issuer's logo is available
/// it appears on a white tile over the badge once it has loaded; if it cannot load, the badge stays.
struct CardBadge: View {
    let code: String
    var color: Color
    var size: CGFloat = 40
    /// Gray version used for a card that has no details yet.
    var isMuted = false
    /// An SF Symbol shown instead of the letters, on a gray badge (used for banks that are not listed).
    var systemImage: String?
    /// The issuer's logo. Not shown on the gray badge of a card with no details.
    var logoURL: URL?

    private var isGray: Bool { isMuted || systemImage != nil }
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
    }

    var body: some View {
        Group {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.42, weight: .medium))
            } else {
                Text(code)
                    .font(.app(size * 0.33, .bold))
            }
        }
        .foregroundStyle(isGray ? Theme.textSecondary : Color.white)
        .frame(width: size, height: size)
        .background(isGray ? Theme.mutedBadge : color, in: shape)
        .overlay {
            if let logoURL {
                AsyncImage(url: logoURL, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .padding(size * 0.16)
                            .frame(width: size, height: size)
                            .background(Color.white, in: shape)
                            .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
                    case .failure(let error):
                        // The colored badge underneath stays. This only prints why, in debug builds.
                        Color.clear
                            .frame(width: 0, height: 0)
                            .onAppear { LogoService.reportFailure(for: logoURL, error: error) }
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

extension CardBadge {
    init(issuer: Issuer, size: CGFloat = 40, isMuted: Bool = false) {
        self.init(
            code: issuer.badgeCode,
            color: Color(hex: issuer.badgeColorHex),
            size: size,
            isMuted: isMuted,
            systemImage: issuer.isCustom ? "creditcard" : nil,
            logoURL: isMuted ? nil : issuer.logoURL
        )
    }
}

#Preview("Badges") {
    HStack(spacing: 12) {
        CardBadge(code: "CH", color: Color(hex: 0x1F5BC4))
        CardBadge(code: "AX", color: Color(hex: 0x2A6F8E))
        CardBadge(code: "C1", color: Color(hex: 0xB02A37))
        CardBadge(code: "CH", color: Color(hex: 0x1F5BC4), isMuted: true)
    }
    .padding(24)
    .background(Theme.background)
}
