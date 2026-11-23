import SwiftUI

/// One issuer in the "Pick your cards" list: badge, name, a checkbox, and, once ticked, a − / + counter
/// for how many cards the user has from it.
struct IssuerPickRow: View {
    let issuer: Issuer
    /// Cards picked from this issuer. 0 means the row is not ticked.
    let count: Int
    /// Cards the user already added (second pick screen). Those cannot be unticked or counted away,
    /// but the user can add more.
    var lockedCount = 0
    var maxCount = IssuerPick.maxCount
    let onToggle: () -> Void
    let onIncrease: () -> Void
    let onDecrease: () -> Void

    private var isSelected: Bool { count > 0 }
    private var isLocked: Bool { lockedCount > 0 }

    var body: some View {
        HStack(spacing: 12) {
            // Everything left of the counter is one big tap target that ticks or unticks the issuer.
            Button(action: toggle) {
                HStack(spacing: 14) {
                    CardBadge(issuer: issuer)

                    Text(issuer.name)
                        .font(.app(16, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(isLocked ? 0.6 : 1)
            .accessibilityValue(countDescription)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityHint(isLocked ? "Already added" : "")

            if isSelected {
                CountStepper(
                    count: count,
                    issuerName: issuer.name,
                    canDecrease: count > max(lockedCount, 1),
                    canIncrease: count < maxCount,
                    onIncrease: onIncrease,
                    onDecrease: onDecrease
                )
            }

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

    /// An issuer the user already has cards from cannot be unticked.
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

/// "−  2  +": how many cards the user has from one issuer.
private struct CountStepper: View {
    let count: Int
    let issuerName: String
    let canDecrease: Bool
    let canIncrease: Bool
    let onIncrease: () -> Void
    let onDecrease: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            stepButton("minus", label: "Fewer \(issuerName) cards", isEnabled: canDecrease, action: onDecrease)

            Text("\(count)")
                .font(.app(16, .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 20)
                .accessibilityLabel("\(count) \(issuerName) cards")

            stepButton("plus", label: "More \(issuerName) cards", isEnabled: canIncrease, action: onIncrease)
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
                .frame(width: 30, height: 30)
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
        IssuerPickRow(issuer: BuiltInIssuers.all[0], count: 2, onToggle: {}, onIncrease: {}, onDecrease: {})
        IssuerPickRow(issuer: BuiltInIssuers.all[1], count: 1, onToggle: {}, onIncrease: {}, onDecrease: {})
        IssuerPickRow(issuer: BuiltInIssuers.all[2], count: 0, onToggle: {}, onIncrease: {}, onDecrease: {})
        IssuerPickRow(issuer: BuiltInIssuers.all[10], count: 3, lockedCount: 2, onToggle: {}, onIncrease: {}, onDecrease: {})
    }
    .padding(24)
    .background(Theme.background)
}
