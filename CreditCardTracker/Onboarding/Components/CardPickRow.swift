import SwiftUI

/// One card in the "Pick your cards" list: badge, name, issuer and a checkbox. Once the card is ticked,
/// a "How many do you have?" line with a − / + counter appears under it, for a user with several copies.
struct CardPickRow: View {
    let card: CatalogCard
    /// Copies picked. 0 means the row is not ticked.
    let count: Int
    /// Copies the user already added (second pick screen). Those cannot be unticked or counted away,
    /// but the user can add more.
    var lockedCount = 0
    var maxCount = CardCopies.maximum
    let onToggle: () -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void

    private var isSelected: Bool { count > 0 }
    private var isLocked: Bool { lockedCount > 0 }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                // Everything left of the checkbox is one big tap target that ticks or unticks the card.
                Button(action: toggle) {
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

                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isLocked ? 0.6 : 1)
                .accessibilityValue(countDescription)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityHint(isLocked ? "Already added" : "")

                // The checkbox is tappable too. VoiceOver uses the button on the left instead.
                Button(action: toggle) {
                    Checkbox(isOn: isSelected)
                        .frame(width: 32, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isLocked ? 0.6 : 1)
                .accessibilityHidden(true)
            }

            if isSelected {
                HStack(spacing: 12) {
                    Text("How many do you have?")
                        .font(.app(14))
                        .foregroundStyle(Theme.textSecondary)

                    Spacer(minLength: 8)

                    CountStepper(
                        count: count,
                        cardName: card.name,
                        canDecrease: count > max(lockedCount, 1),
                        canIncrease: count < maxCount,
                        onIncrease: onIncrease,
                        onDecrease: onDecrease
                    )
                }
                .padding(.top, 12)
                .overlay(alignment: .top) {
                    Theme.border.frame(height: 1)
                }
            }
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
        .accessibilityElement(children: .contain)
    }

    /// A card the user already added cannot be unticked.
    private func toggle() {
        if !isLocked { onToggle() }
    }

    private var countDescription: String {
        switch count {
        case 0: return "Not selected"
        case 1: return "1 card"
        default: return "\(count) cards"
        }
    }
}

/// "−  2  +": how many copies of one card the user has.
private struct CountStepper: View {
    let count: Int
    let cardName: String
    let canDecrease: Bool
    let canIncrease: Bool
    let onIncrease: () -> Void
    let onDecrease: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            stepButton("minus", label: "Fewer \(cardName) cards", isEnabled: canDecrease, action: onDecrease)

            Text("\(count)")
                .font(.app(16, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 24)
                .accessibilityLabel("\(count) \(cardName) cards")

            stepButton("plus", label: "More \(cardName) cards", isEnabled: canIncrease, action: onIncrease)
        }
    }

    private func stepButton(
        _ systemImage: String,
        label: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(isEnabled ? Theme.accentText : Theme.textSecondary.opacity(0.4))
                .frame(width: 32, height: 32)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
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
        CardPickRow(card: CardCatalog.all[0], count: 1, onToggle: {}, onIncrease: {}, onDecrease: {})
        CardPickRow(card: CardCatalog.all[1], count: 3, onToggle: {}, onIncrease: {}, onDecrease: {})
        CardPickRow(card: CardCatalog.all[2], count: 0, onToggle: {}, onIncrease: {}, onDecrease: {})
        // Already added: dimmed, cannot be unticked, but one more copy can be added.
        CardPickRow(card: CardCatalog.all[3], count: 2, lockedCount: 2, onToggle: {}, onIncrease: {}, onDecrease: {})
    }
    .padding(24)
    .background(Theme.background)
}
