import SwiftUI

/// Filled purple button ("Continue with 2 cards", "Next card", "Confirm and finish").
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(16, .semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.controlHeight)
            .background(
                Theme.accent.opacity(isEnabled ? 1 : 0.4),
                in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outlined button on a card-colored surface ("Continue with Google", "Skip details for now").
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(16, .semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.Metrics.controlHeight)
            .background(
                Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Plain purple text link ("Log in", "My card is not listed", "Edit").
struct TextLinkButtonStyle: ButtonStyle {
    var weight: Font.Weight = .semibold
    var size: CGFloat = 15
    var color: Color = Theme.accentText

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(size, weight))
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == TextLinkButtonStyle {
    static var textLink: TextLinkButtonStyle { TextLinkButtonStyle() }

    /// A text link with a custom size, weight or color (for example the red "Remove this card").
    static func customTextLink(
        size: CGFloat = 15,
        weight: Font.Weight = .semibold,
        color: Color = Theme.accentText
    ) -> TextLinkButtonStyle {
        TextLinkButtonStyle(weight: weight, size: size, color: color)
    }
}
