import SwiftUI

/// The By bank view: the cards grouped under their bank, with the bank's totals and its Pay link.
struct ByBankModeView: View {
    let data: DashboardData
    let onEdit: (UUID) -> Void
    let onPay: (URL) -> Void

    var body: some View {
        let groups = BankGroup.groups(from: data.cards)

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("By bank")
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text(groups.count == 1 ? "1 bank" : "\(groups.count) banks")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            ForEach(groups) { group in
                BankGroupCard(group: group, onEdit: onEdit, onPay: onPay)
            }

            ForEach(data.incomplete) { card in
                IncompleteCardRow(card: card) { onEdit(card.id) }
            }

            if !data.incomplete.isEmpty {
                Text("Totals count only cards with complete details.")
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// One bank: a header with the bank's name and totals, a line for each of its cards, and "Pay Chase ↗".
private struct BankGroupCard: View {
    let group: BankGroup
    let onEdit: (UUID) -> Void
    let onPay: (URL) -> Void

    /// Space to the left of the card lines: the row's padding, the badge and the gap after it.
    private static let textInset: CGFloat = 14 + 40 + 14

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ForEach(group.cards) { item in
                Theme.border.frame(height: 1)
                cardLine(item)
            }

            if let bank = group.payBank, let url = bank.url {
                Theme.border.frame(height: 1)
                Button { onPay(url) } label: {
                    HStack(spacing: 4) {
                        Text(bank.buttonTitle)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.leading, Self.textInset)
                    .padding(.trailing, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TextLinkButtonStyle(size: 14))
                .accessibilityLabel("\(bank.buttonTitle), \(group.name)")
                .accessibilityHint("Opens the lender's website or app")
            }
        }
        .dashboardCardStyle()
    }

    private var header: some View {
        HStack(spacing: 14) {
            if let first = group.cards.first {
                CardBadge(card: first.card.catalogCard)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(group.name)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(group.cards.count == 1 ? "1 card" : "\(group.cards.count) cards")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                Text(group.totalBalance.usd)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text("Min \(group.totalMinimums.usd)")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(14)
        .accessibilityElement(children: .combine)
    }

    private func cardLine(_ item: DashboardCard) -> some View {
        Button { onEdit(item.id) } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.card.catalogCard.displayName)
                        .font(.app(14, .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    DueLine(item: item)
                }

                Spacer(minLength: 8)

                Text(item.balance.usd)
                    .font(.app(14, .semibold))
                    .foregroundStyle(Theme.textPrimary)
            }
            .accessibilityElement(children: .combine)
            .padding(.leading, Self.textInset)
            .padding(.trailing, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint("Opens this card to pay or mark it paid")
    }
}

#Preview("By bank – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}
