import SwiftUI

/// The Interest view: cards with the highest interest rate (APR) first, and about what a month of
/// interest costs if the balances are carried over.
struct InterestModeView: View {
    let data: DashboardData
    let onEdit: (UUID) -> Void

    var body: some View {
        let summary = InterestSummary(cards: data.cards)

        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Highest interest first")
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Text("Sorted by APR (the yearly interest rate)")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            estimate(summary)

            VStack(spacing: 12) {
                ForEach(summary.rows) { row in
                    InterestRowView(row: row) { onEdit(row.id) }
                }
            }

            Text("Estimates are balance × APR ÷ 12 and only apply when a balance is carried over.")
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            if !data.incomplete.isEmpty {
                Text("Cards without details are left out.")
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    /// The tinted box: "If you carry these balances, interest is about $108.07 a month".
    private func estimate(_ summary: InterestSummary) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if summary.countedCards > 0 {
                Text("If you carry these balances, interest is about")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondaryOnTint)
                Text("\(summary.monthlyTotal.usd) a month")
                    .font(.app(26, .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(summary.note)
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondaryOnTint)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Add an interest rate (APR) to a card to see an estimate.")
                    .font(.app(14))
                    .foregroundStyle(Theme.textSecondaryOnTint)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

/// One card: badge, name, balance, and on the right its APR and what a month of interest costs.
private struct InterestRowView: View {
    let row: InterestRow
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            HStack(spacing: 14) {
                CardBadge(card: row.card.card.catalogCard)

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.card.card.catalogCard.displayName)
                        .font(.app(16, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Balance \(row.card.balance.usd)")
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                    if row.apr == nil {
                        Text("Add APR")
                            .font(.app(14, .semibold))
                            .foregroundStyle(Theme.accentText)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 8)

                if let aprText = row.aprText {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(aprText)
                            .font(.app(18, .bold))
                            .foregroundStyle(Theme.textPrimary)
                        if let monthly = row.monthlyInterest {
                            Text("≈ \(monthly.usd) a month")
                                .font(.app(13))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                } else {
                    Text("APR not added")
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .padding(14)
            .dashboardCardStyle()
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityHint(row.apr == nil ? "Add the interest rate" : "Edit this card")
    }
}

#Preview("Interest – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}
