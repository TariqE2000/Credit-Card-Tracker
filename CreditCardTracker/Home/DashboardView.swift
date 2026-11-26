import SwiftUI

/// The home screen: totals, the card due next, and every card in a list the user can sort.
/// Shown after "Confirm and finish".
struct DashboardView: View {
    @EnvironmentObject private var store: OnboardingStore
    /// The sort the user picked last time, kept on the phone.
    @AppStorage("dashboardSort") private var sortName = CardSort.dueDate.rawValue

    private var sort: CardSort {
        CardSort(rawValue: sortName) ?? .dueDate
    }

    var body: some View {
        let data = DashboardData(cards: store.cards, sortedBy: sort)

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                SummaryCard(data: data)

                if let dueSoon = data.dueSoon {
                    DueSoonBanner(card: dueSoon)
                }

                cardList(data)

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
    }

    // MARK: Pieces

    private var header: some View {
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
                DashboardCardRow(item: item, sort: sort)
            }

            ForEach(data.incomplete) { card in
                IncompleteCardRow(card: card)
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

/// The card due next, shown when it is due within the week.
private struct DueSoonBanner: View {
    let card: DashboardCard

    var body: some View {
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
        .padding(16)
        .background(
            Theme.accentTint,
            in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Rows

/// One card with complete details: badge, name, due date, balance and a second line that follows the sort.
private struct DashboardCardRow: View {
    let item: DashboardCard
    let sort: CardSort

    var body: some View {
        HStack(spacing: 14) {
            CardBadge(card: item.card.catalogCard)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.card.catalogCard.displayName)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 0) {
                    Text("Due \(item.dueOnText) · ")
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                    Text(item.whenText)
                        .font(.app(13, item.urgency == .calm ? .regular : .semibold))
                        .foregroundStyle(whenColor)
                }
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
        .padding(14)
        .dashboardCardStyle()
        .accessibilityElement(children: .combine)
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

    var body: some View {
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

            Spacer(minLength: 0)
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
