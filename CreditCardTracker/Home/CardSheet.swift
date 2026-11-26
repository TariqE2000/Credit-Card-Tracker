import SwiftUI

/// What opens when you tap a card that has its details filled in: the card's numbers, "Pay Chase",
/// one button that follows whether this month's payment is marked as paid ("Mark paid" or "Mark unpaid"),
/// and "Edit card details". A card with missed payments also gets a note, and "Mark paid" clears them.
///
/// The sheet reads the card from the store each time it draws, so it changes the moment the button is tapped.
struct CardSheet: View {
    let cardID: UUID
    /// Called by "Edit card details". The screen under the sheet closes it and opens the full form.
    let onEdit: () -> Void

    @EnvironmentObject private var store: OnboardingStore
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss

    /// How tall the content is, so the sheet is only as tall as it needs to be.
    @State private var contentHeight: CGFloat = 560

    /// The card as it is right now. Nil if it was removed, or lost a detail.
    private var item: DashboardCard? {
        DashboardData(cards: store.cards, sortedBy: .dueDate, paid: store.paidDueDates, settled: store.settledDueDates)
            .cards.first { $0.id == cardID }
    }

    var body: some View {
        ScrollView {
            if let item {
                content(item)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: SheetHeightKey.self, value: proxy.size.height)
                        }
                    )
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(SheetHeightKey.self) { height in
            if height > 0 { contentHeight = height }
        }
        .background(Theme.surface.ignoresSafeArea())
        .presentationBackground(Theme.surface)
        .presentationDragIndicator(.visible)
        .presentationDetents([.height(contentHeight + 24), .large])
        .onChange(of: item == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }

    // MARK: Pieces

    private func content(_ item: DashboardCard) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            header(item)
            numbers(item)

            if let notice = item.missedNotice {
                Text(notice)
                    .font(.app(13))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Theme.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let url = item.payURL {
                Button { openURL(url) } label: {
                    HStack(spacing: 6) {
                        Text(item.payTitle)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .accessibilityLabel("\(item.payTitle), \(name(item))")
                .accessibilityHint("Opens the lender's website or app")
            }

            VStack(spacing: 8) {
                Button {
                    store.togglePaid(item)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showsUnpaid(item) ? "arrow.uturn.backward" : "checkmark.circle")
                        Text(showsUnpaid(item) ? "Mark unpaid" : "Mark paid")
                    }
                }
                .buttonStyle(SecondaryButtonStyle())

                Text(caption(item))
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button("Edit card details", action: onEdit)
                .buttonStyle(TextLinkButtonStyle())
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.top, 28)
        .padding(.bottom, 12)
    }

    private func header(_ item: DashboardCard) -> some View {
        HStack(spacing: 14) {
            CardBadge(card: item.card.catalogCard, size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(name(item))
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if item.isMissed {
                    missedLine(item)
                } else {
                    DueLine(item: item)
                }
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// "Missed Nov 20 · 6 days ago": the first part in red, the rest in gray.
    private func missedLine(_ item: DashboardCard) -> some View {
        HStack(alignment: .top, spacing: 5) {
            Image(systemName: "exclamationmark.circle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.danger)
                .padding(.top, 3)
                .accessibilityHidden(true)
            Text(item.missedHeadline ?? "")
                .font(.app(13, .semibold))
                .foregroundStyle(Theme.danger)
            + Text(item.missedTail.map { " · \($0)" } ?? "")
                .font(.app(13))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func numbers(_ item: DashboardCard) -> some View {
        HStack(alignment: .top, spacing: 12) {
            stat("Balance", item.balance.usd)
            if item.isMissed {
                // Three columns need the shorter name. "Next due" is the coming payment, not a missed one.
                stat("Minimum", item.minimumPayment.usd)
                stat("Next due", item.dueOnText)
            } else {
                stat("Minimum payment", item.minimumPayment.usd)
            }
        }
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Theme.border.frame(height: 1) }
        .overlay(alignment: .bottom) { Theme.border.frame(height: 1) }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.app(18, .bold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func name(_ item: DashboardCard) -> String {
        item.card.catalogCard.displayName
    }

    /// "Mark unpaid" only when the coming payment is marked paid and nothing is missed. With missed payments
    /// the button is "Mark paid", and it clears them.
    private func showsUnpaid(_ item: DashboardCard) -> Bool {
        item.isPaid && !item.isMissed
    }

    /// The line under the button: where "Mark paid" moves the card to, or what "Mark unpaid" brings back.
    private func caption(_ item: DashboardCard) -> String {
        if let missed = item.missedCaption { return missed }
        if item.isPaid {
            if let paid = item.paidDueText {
                return "Brings this month's \(paid) due date back."
            }
            return "Brings this month's due date back."
        }
        if let after = item.afterDueText {
            return "Moves this card to next month's due date, \(after). You can switch it back any time."
        }
        return "Moves this card to next month's due date. You can switch it back any time."
    }
}

/// Carries the height of the sheet's content up to the sheet.
private struct SheetHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Opening it

extension View {
    /// Tapping a card opens its sheet (`opened`). "Edit card details" in the sheet closes it and then opens the
    /// full form (`editing`), the same form used during setup. Cards that still need details go straight to the form.
    func cardSheets(opened: Binding<EditTarget?>, editing: Binding<EditTarget?>) -> some View {
        modifier(CardSheetsModifier(opened: opened, editing: editing))
    }
}

private struct CardSheetsModifier: ViewModifier {
    @Binding var opened: EditTarget?
    @Binding var editing: EditTarget?
    /// The card to edit as soon as the sheet has closed. A second sheet cannot open while the first is closing.
    @State private var editWhenClosed: EditTarget?

    func body(content: Content) -> some View {
        content
            .sheet(item: $opened, onDismiss: openFormIfAsked) { target in
                CardSheet(cardID: target.id) {
                    editWhenClosed = target
                    opened = nil
                }
            }
            .sheet(item: $editing) { target in
                EditCardSheet(cardID: target.id)
            }
    }

    private func openFormIfAsked() {
        guard let target = editWhenClosed else { return }
        editWhenClosed = nil
        editing = target
    }
}

@MainActor
private func cardSheetPreview() -> some View {
    let store = viewsPreviewStore()
    return CardSheet(cardID: store.cards[0].id, onEdit: {})
        .environmentObject(store)
}

#Preview("Card sheet") {
    cardSheetPreview()
}
