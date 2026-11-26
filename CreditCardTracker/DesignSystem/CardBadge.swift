import SwiftUI
import UIKit

/// Logos shipped inside the app: `Assets.xcassets/IssuerLogos`, one image set per issuer, named
/// "logo-" plus the issuer's opencard-db ID ("logo-chase"). To add one, see docs/issuer-logos.md.
enum BundledLogo {
    /// The image set to show for this card, or nil when the app has no logo bundled for its issuer.
    static func imageName(for card: CatalogCard) -> String? {
        guard let name = card.bundledLogoName, UIImage(named: name) != nil else { return nil }
        return name
    }
}

/// Rounded square with the issuer abbreviation ("CH", "AX", "C1"). When the issuer's logo is available
/// it appears on a white tile over the badge: a bundled logo straight away, or a downloaded one once it
/// has loaded. If neither is available, or the download fails, the badge stays.
struct CardBadge: View {
    let code: String
    var color: Color
    var size: CGFloat = 40
    /// Gray version used for a card that has no details yet.
    var isMuted = false
    /// An SF Symbol shown instead of the letters, on a gray badge (used for cards that are not listed).
    var systemImage: String?
    /// A logo bundled in the app. Used instead of `logoURL` when there is one. Not shown on the gray badge
    /// of a card with no details.
    var logoImageName: String?
    /// A logo to download. Not shown on the gray badge of a card with no details.
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
            if let logoImageName {
                logoTile(Image(logoImageName))
            } else if let logoURL {
                AsyncImage(url: logoURL, transaction: Transaction(animation: .easeIn(duration: 0.2))) { phase in
                    switch phase {
                    case .success(let image):
                        logoTile(image)
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

    /// A logo on a white tile with a thin border, the same size as the badge.
    private func logoTile(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .padding(size * 0.16)
            .frame(width: size, height: size)
            .background(Color.white, in: shape)
            .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
    }
}

extension CardBadge {
    init(card: CatalogCard, size: CGFloat = 40, isMuted: Bool = false) {
        // A bundled logo wins, so nothing is downloaded for an issuer the app already has a logo for.
        let bundled = isMuted ? nil : BundledLogo.imageName(for: card)
        self.init(
            code: card.badgeCode,
            color: Color(hex: card.badgeColorHex),
            size: size,
            isMuted: isMuted,
            systemImage: card.isCustom ? "creditcard" : nil,
            logoImageName: bundled,
            logoURL: (isMuted || bundled != nil) ? nil : card.logoURL
        )
    }
}

#Preview("Badges") {
    HStack(spacing: 12) {
        CardBadge(code: "CH", color: Color(hex: 0x1F5BC4))
        CardBadge(code: "AX", color: Color(hex: 0x2A6F8E))
        CardBadge(code: "C1", color: Color(hex: 0xB02A37))
        CardBadge(code: "CH", color: Color(hex: 0x1F5BC4), isMuted: true)
        // A logo bundled in the app.
        CardBadge(code: "CH", color: Color(hex: 0x1F5BC4), logoImageName: "logo-chase")
        CardBadge(code: "AX", color: Color(hex: 0x2A6F8E), logoImageName: "logo-amex")
    }
    .padding(24)
    .background(Theme.background)
}
