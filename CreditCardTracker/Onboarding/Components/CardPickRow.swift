import SwiftUI

/// One tappable card in the "Pick your cards" list: badge, name, issuer and a checkbox.
struct CardPickRow: View {
    let card: Issuer
    let isSelected: Bool
    /// A card the user already added. Shown ticked and dimmed, and it cannot be tapped.
    var isLocked = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                CardBadge(card: card)

                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name)
                        .font(.app(16, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                    Text(card.issuer)
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)

                Checkbox(isOn: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? Theme.accentTint : Theme.surface,
                in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(isSelected ? Theme.accent : Theme.border, lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .opacity(isLocked ? 0.6 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isLocked ? "Already added" : "")
    }
}

private struct Checkbox: View {
    let isOn: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isOn ? Theme.accent : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent : Theme.textSecondary.opacity(0.5), lineWidth: 1.5)
            )
            .overlay {
                if isOn {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.white)
                }
            }
            .frame(width: 22, height: 22)
            .accessibilityHidden(true)
    }
}

#Preview("Rows") {
    VStack(spacing: 10) {
        CardPickRow(card: BuiltInIssuers.all[0], isSelected: true) {}
        CardPickRow(card: BuiltInIssuers.all[2], isSelected: false) {}
    }
    .padding(24)
    .background(Theme.background)
}
