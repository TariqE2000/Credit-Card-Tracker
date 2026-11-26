import SwiftUI

/// The By week view: what is due each week, with the week's minimums added up.
struct ByWeekModeView: View {
    let data: DashboardData
    let onEdit: (UUID) -> Void
    let onPay: (URL) -> Void
    let onTogglePaid: (DashboardCard) -> Void

    var body: some View {
        let sections = WeekSection.sections(from: data.cards)

        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Due by week")
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Minimum payments by week")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(sections) { section in
                weekSection(section)
            }

            Text(footnote)
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
    }

    private var footnote: String {
        data.incomplete.isEmpty
            ? "Each week adds up the minimums due."
            : "Each week adds up the minimums due. Cards without details are left out."
    }

    private func weekSection(_ section: WeekSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(section.title)
                        .font(.app(16, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    if let dates = section.dates {
                        Text(dates)
                            .font(.app(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(section.totalMinimums.usd)
                        .font(.app(16, .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(section.cards.count == 1 ? "1 card" : "\(section.cards.count) cards")
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, 2)
            .accessibilityElement(children: .combine)

            ForEach(section.cards) { item in
                PayableRow(
                    payURL: item.payURL,
                    payTitle: item.payTitle,
                    name: item.card.catalogCard.displayName,
                    isPaid: item.isPaid,
                    onEdit: { onEdit(item.id) },
                    onPay: onPay,
                    onTogglePaid: { onTogglePaid(item) }
                ) {
                    HStack(spacing: 14) {
                        CardBadge(card: item.card.catalogCard)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.card.catalogCard.displayName)
                                .font(.app(16, .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            DueLine(item: item, showsWeekday: true)
                        }

                        Spacer(minLength: 8)

                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.minimumPayment.usd)
                                .font(.app(16, .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("minimum")
                                .font(.app(13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
    }
}

#Preview("By week – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}
