import SwiftUI

/// The home screen: totals, the card due next, and every card in a list the user can sort.
/// Tapping a card opens its details to edit. "Pay" opens the lender's page, "Mark paid" moves a card on to
/// next month's due day. Shown after "Confirm and finish".
struct DashboardView: View {
    @EnvironmentObject private var store: OnboardingStore
    /// Opens a web address the way the phone normally does: in Safari, or in the bank's app if it is
    /// installed and the bank has set the link up to open there.
    @Environment(\.openURL) private var openURL
    /// The sort the user picked last time, kept on the phone.
    @AppStorage("dashboardSort") private var sortName = CardSort.dueDate.rawValue
    /// The card whose details are open. Nil when no card is being edited.
    @State private var editing: EditTarget?
    /// The card just marked as paid, so the "Undo" bar can offer to take it back for a few seconds.
    @State private var justPaid: PaidNotice?

    private var sort: CardSort {
        CardSort(rawValue: sortName) ?? .dueDate
    }

    var body: some View {
        let data = DashboardData(cards: store.cards, sortedBy: sort, paid: store.paidDueDates)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                SummaryCard(data: data)

                if let dueSoon = data.dueSoon {
                    DueSoonBanner(
                        card: dueSoon,
                        onPay: { openURL($0) },
                        onMarkPaid: { markPaid(dueSoon) }
                    )
                }

                if data.cards.isEmpty && data.incomplete.isEmpty {
                    Text("No cards yet. Tap + to add one.")
                        .font(.app(15))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 8)
                } else {
                    cardList(data)
                }

                if !data.incomplete.isEmpty {
                    Text("Totals count only cards with complete details.")
                        .font(.app(12))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, Theme.Metrics.screenPadding)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Theme.background.ignoresSafeArea())
        .sheet(item: $editing) { target in
            EditCardSheet(cardID: target.id)
        }
        .sheet(isPresented: addingCards) {
            AddCardSheet()
        }
        .safeAreaInset(edge: .bottom) {
            if let notice = justPaid {
                PaidUndoBar(name: notice.name) { undoPaid(notice.id) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Hides the bar after a few seconds. Starts over when another card is marked, and ends at once
        // when the bar is closed by "Undo".
        .task(id: justPaid?.id) {
            guard justPaid != nil else { return }
            do {
                try await Task.sleep(for: .seconds(6))
            } catch {
                return
            }
            withAnimation { justPaid = nil }
        }
    }

    // MARK: Actions

    /// The "+" sheet is open while the store says so. Swiping it down tells the store it was cancelled.
    private var addingCards: Binding<Bool> {
        Binding(
            get: { store.isAddingFromHome },
            set: { isOpen in
                if !isOpen { store.cancelAddingFromHome() }
            }
        )
    }

    private func markPaid(_ item: DashboardCard) {
        store.markPaid(item.id, dueDate: item.nextDueDate)
        withAnimation { justPaid = PaidNotice(id: item.id, name: item.card.catalogCard.displayName) }
    }

    private func undoPaid(_ id: UUID) {
        store.undoPaid(id)
        withAnimation { justPaid = nil }
    }

    // MARK: Pieces

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.app(13, .medium))
                    .foregroundStyle(Theme.textSecondary)
                Text("Your cards")
                    .font(.app(28, .bold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)

            Spacer(minLength: 8)

            addButton
        }
    }

    /// The round "+" at the top right. Opens the card picker in a sheet.
    private var addButton: some View {
        Button {
            store.startAddingFromHome()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 44, height: 44)
                .background(Theme.accent, in: Circle())
        }
        .accessibilityLabel("Add a card")
    }

    private func cardList(_ data: DashboardData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All cards")
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 8)

                sortMenu
            }

            ForEach(data.cards) { item in
                DashboardCardRow(
                    item: item,
                    sort: sort,
                    onEdit: { editing = EditTarget(id: item.id) },
                    onPay: { openURL($0) },
                    onMarkPaid: { markPaid(item) },
                    onUndoPaid: { undoPaid(item.id) }
                )
            }

            ForEach(data.incomplete) { card in
                IncompleteCardRow(card: card) {
                    editing = EditTarget(id: card.id)
                }
            }
        }
    }

    /// "Due date ⌄". Tapping it opens the list of sorts, with a check next to the current one.
    private var sortMenu: some View {
        Menu {
            Picker("Sort cards by", selection: $sortName) {
                ForEach(CardSort.allCases) { option in
                    Text(option.menuTitle).tag(option.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(sort.title)
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .font(.app(14, .medium))
            .foregroundStyle(Theme.accentText)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("Sort cards")
        .accessibilityValue(sort.title)
    }
}

// MARK: - Total balance

/// Total balance, then total minimums, what is due this week, and the next due date.
private struct SummaryCard: View {
    let data: DashboardData

    private var countText: String {
        data.cards.count == 1 ? "1 card" : "\(data.cards.count) cards"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total balance")
                        .font(.app(13, .medium))
                        .foregroundStyle(Theme.textSecondary)
                    Text(data.totalBalance.usd)
                        .font(.app(34, .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 8)

                Text(countText)
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }
            .accessibilityElement(children: .combine)

            Theme.border.frame(height: 1)

            HStack(alignment: .top, spacing: 12) {
                stat("Total minimums", data.totalMinimums.usd)
                stat("Due in \(DashboardData.dueSoonDays) days", data.dueSoonTotal.usd)
                stat("Next due", data.nextDue?.dueOnText ?? "–")
            }
        }
        .padding(20)
        .dashboardCardStyle()
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.app(16, .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Due soon

/// The card due next, shown when it is due within the week. "Pay" opens the lender's page and
/// "Mark paid" moves the card on to next month's due day.
private struct DueSoonBanner: View {
    let card: DashboardCard
    let onPay: (URL) -> Void
    let onMarkPaid: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.dueChipText)
                    .font(.app(12, .semibold))
                    .foregroundStyle(card.urgency == .urgent ? Theme.danger : Theme.accentText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Theme.surface, in: Capsule())

                Text(card.card.catalogCard.displayName)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Minimum \(card.minimumPayment.usd) · \(card.dueOnText)")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondaryOnTint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            HStack(spacing: 10) {
                if let url = card.payURL {
                    // The title names the lender the link opens, e.g. "Pay Capital One".
                    Button { onPay(url) } label: {
                        HStack(spacing: 6) {
                            Text(card.payTitle)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompactPayButtonStyle())
                    .accessibilityLabel("\(card.payTitle), \(card.card.catalogCard.displayName)")
                    .accessibilityHint("Opens the lender's website or app")

                    Button("Mark paid", action: onMarkPaid)
                        .buttonStyle(TextLinkButtonStyle(size: 15))
                        .frame(minWidth: 88, minHeight: 44)
                        .accessibilityHint("Moves this card on to next month's due date")
                } else {
                    // No lender page to open for this card, so marking it paid is the one action.
                    Button { onMarkPaid() } label: {
                        Text("Mark paid")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CompactPayButtonStyle())
                    .accessibilityHint("Moves this card on to next month's due date")
                }
            }
        }
        .padding(16)
        .background(
            Theme.accentTint,
            in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
        )
    }
}

/// The filled purple button in the banner. Smaller than the full-width buttons in onboarding.
private struct CompactPayButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.app(15, .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Theme.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - Rows

/// One card with complete details: badge, name, due date, balance and a second line that follows the sort.
/// Under the due date is a "Pay Chase"-style link when the lender has one. Pressing and holding offers "Mark paid".
private struct DashboardCardRow: View {
    let item: DashboardCard
    let sort: CardSort
    let onEdit: () -> Void
    let onPay: (URL) -> Void
    let onMarkPaid: () -> Void
    let onUndoPaid: () -> Void

    /// Space to the left of the text: the row's padding, the badge and the gap after it.
    private static let textInset: CGFloat = 14 + 40 + 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                content
                    .padding(.top, 14)
                    .padding(.horizontal, 14)
                    .padding(.bottom, item.payURL == nil ? 14 : 2)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityHint("Edit this card")

            if let url = item.payURL {
                Button { onPay(url) } label: {
                    HStack(spacing: 4) {
                        Text(item.payTitle)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(minHeight: 40, alignment: .leading)
                    .padding(.leading, Self.textInset)
                    .padding(.trailing, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TextLinkButtonStyle(size: 14))
                .accessibilityLabel("\(item.payTitle), \(item.card.catalogCard.displayName)")
                .accessibilityHint("Opens the lender's website or app")
            }
        }
        .dashboardCardStyle()
        .contextMenu {
            if item.isPaid {
                Button(action: onUndoPaid) {
                    Label("Undo mark as paid", systemImage: "arrow.uturn.backward")
                }
            } else {
                Button(action: onMarkPaid) {
                    Label("Mark paid", systemImage: "checkmark.circle")
                }
                if let url = item.payURL {
                    Button { onPay(url) } label: {
                        Label(item.payTitle, systemImage: "arrow.up.right")
                    }
                }
            }
        }
    }

    private var content: some View {
        HStack(spacing: 14) {
            CardBadge(card: item.card.catalogCard)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.card.catalogCard.displayName)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                dueLine
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(item.balance.usd)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(detailText)
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Due Nov 28 · in 2 days", or "Paid · next due Dec 28" once this month's payment is marked paid.
    @ViewBuilder
    private var dueLine: some View {
        if item.isPaid {
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accentText)
                    .accessibilityHidden(true)
                Text("Paid · next due \(item.dueOnText)")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }
        } else {
            HStack(spacing: 0) {
                Text("Due \(item.dueOnText) · ")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
                Text(item.whenText)
                    .font(.app(13, item.urgency == .calm ? .regular : .semibold))
                    .foregroundStyle(whenColor)
            }
        }
    }

    private var whenColor: Color {
        switch item.urgency {
        case .urgent: return Theme.danger
        case .soon: return Theme.accentText
        case .calm: return Theme.textSecondary
        }
    }

    /// Under the balance: the minimum payment, or the bank or interest rate when the list is sorted by those.
    private var detailText: String {
        switch sort {
        case .bank:
            return item.card.catalogCard.issuer
        case .interestRate:
            guard let apr = item.apr else { return "No APR" }
            return "\(FormInput.text(for: apr))% APR"
        case .dueDate, .balance, .minimumPayment:
            return "Min \(item.minimumPayment.usd)"
        }
    }
}

/// A card that is missing details: dashed outline, gray badge, and a note that it is not in the totals.
private struct IncompleteCardRow: View {
    let card: TrackedCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            content
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint("Add the missing details")
    }

    private var content: some View {
        HStack(spacing: 14) {
            CardBadge(card: card.catalogCard, isMuted: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(card.catalogCard.displayName)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Incomplete · not in your totals")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            Text("Add details")
                .font(.app(15, .semibold))
                .foregroundStyle(Theme.accentText)
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(
                    Theme.textSecondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Mark paid

/// Which card was just marked as paid, for the "Undo" bar.
private struct PaidNotice: Equatable {
    let id: UUID
    let name: String
}

/// A bar at the bottom of the screen: "Chase Sapphire Preferred marked as paid. Undo".
private struct PaidUndoBar: View {
    let name: String
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("\(name) marked as paid")
                .font(.app(14))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("Undo", action: onUndo)
                .buttonStyle(TextLinkButtonStyle(size: 15))
                .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)
        .dashboardCardStyle()
        .shadow(color: Color.black.opacity(0.08), radius: 8, y: 2)
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 8)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Editing a card

/// Names the card to edit. `sheet(item:)` needs something Identifiable.
private struct EditTarget: Identifiable {
    let id: UUID
}

/// The card form in a sheet, the same form as "Edit" on the review screen. Saving or the back arrow
/// closes it. If the card is removed from inside the form, the sheet closes too.
private struct EditCardSheet: View {
    let cardID: UUID

    @EnvironmentObject private var store: OnboardingStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CardFormView(cardID: cardID, mode: .edit)
        }
        .onChange(of: store.card(withID: cardID) == nil) { _, isRemoved in
            if isRemoved { dismiss() }
        }
    }
}

/// A row that is a button: the whole row is tappable and dims a little while pressed.
private struct RowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

// MARK: - Shared look

private extension View {
    /// White surface with a thin border, like the cards on the review screen.
    func dashboardCardStyle() -> some View {
        background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
    }
}

// MARK: - Previews

#Preview("Dashboard – light") {
    DashboardView()
        .environmentObject(previewStore())
        .preferredColorScheme(.light)
}

#Preview("Dashboard – dark") {
    DashboardView()
        .environmentObject(previewStore())
        .preferredColorScheme(.dark)
}

/// Five cards with details, one without, like the design. The due days are close to today, so the banner shows.
@MainActor
private func previewStore() -> OnboardingStore {
    let store = OnboardingStore()
    for card in CardCatalog.all.prefix(6) {
        store.toggleSelection(of: card)
    }
    store.continueFromPickCards()

    let calendar = Calendar.current
    func due(in days: Int) -> DueDate? {
        let date = calendar.date(byAdding: .day, value: days, to: Date()) ?? Date()
        return DueDate(date: date)
    }

    let samples: [(balance: Decimal, minimum: Decimal, days: Int, apr: Decimal?)] = [
        (2480.15, 75, 2, 24.99),
        (1120.40, 35, 7, 29.74),
        (860, 35, 10, 23.99),
        (640, 25, 13, 21.49),
        (1890.22, 60, 18, nil),
    ]
    for (card, sample) in zip(store.cards, samples) {
        store.saveDetails(
            CardDetails(
                balance: sample.balance,
                minimumPayment: sample.minimum,
                dueDate: due(in: sample.days),
                apr: sample.apr
            ),
            for: card.id
        )
    }
    return store
}
