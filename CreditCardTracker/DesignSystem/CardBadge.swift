import SwiftUI

/// Rounded square with the issuer abbreviation ("CH", "AX", "C1").
struct CardBadge: View {
    let code: String
    var color: Color
    var size: CGFloat = 40
    /// Gray version used for a card that has no details yet.
    var isMuted = false

    var body: some View {
        Text(code)
            .font(.app(size * 0.33, .bold))
            .foregroundStyle(isMuted ? Theme.textSecondary : Color.white)
            .frame(width: size, height: size)
            .background(
                isMuted ? Theme.mutedBadge : color,
                in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
            )
            .accessibilityHidden(true)
    }
}

extension CardBadge {
    init(card: CatalogCard, size: CGFloat = 40, isMuted: Bool = false) {
        self.init(
            code: card.badgeCode,
            color: Color(hex: card.badgeColorHex),
            size: size,
            isMuted: isMuted
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
