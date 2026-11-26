import SwiftUI

/// One card on the review screen. Cards with complete details show balance, minimum and due date;
/// cards without them show a dashed "Incomplete" row with an "Add details" link.
struct ReviewCardRow: View {
    let card: TrackedCard
    /// What to call the card. The store adds a number when the user has several copies of it.
    /// Defaults to the card's name.
    var title: String? = nil
    let onEdit: () -> Void

    private var displayTitle: String { title ?? card.catalogCard.displayName }

    var body: some View {
        if card.detailsComplete {
            completeRow
        } else {
            incompleteRow
        }
    }

    // MARK: Complete

    private var completeRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                CardBadge(card: card.catalogCard)

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle)
                        .font(.app(16, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(subtitle)
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer(minLength: 8)

                Button("Edit", action: onEdit)
                    .buttonStyle(.textLink)
            }
            .padding(14)

            Theme.border.frame(height: 1)

            HStack(alignment: .top, spacing: 8) {
                column("Balance", value: Self.money(card.details.balance))
                column("Minimum", value: Self.money(card.details.minimumPayment))
                column("Due", value: card.details.dueDate?.shortDescription ?? "–")
            }
            .padding(14)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    private func column(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.app(16, .semibold))
                .foregroundStyle(Theme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// "Chase · 24.99% APR", or just "Chase" when no APR was entered.
    private var subtitle: String {
        guard let apr = card.details.apr else { return card.catalogCard.issuer }
        return "\(card.catalogCard.issuer) · \(FormInput.text(for: apr))% APR"
    }

    private static func money(_ value: Decimal?) -> String {
        guard let value else { return "–" }
        return value.formatted(.currency(code: "USD"))
    }

    // MARK: Incomplete

    private var incompleteRow: some View {
        HStack(spacing: 14) {
            CardBadge(card: card.catalogCard, isMuted: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(displayTitle)
                    .font(.app(16, .semibold))
                    .foregroundStyle(Theme.textSecondary)
                Text("Incomplete")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary.opacity(0.8))
            }

            Spacer(minLength: 8)

            Button("Add details", action: onEdit)
                .buttonStyle(.textLink)
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                .strokeBorder(
                    Theme.textSecondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
        .accessibilityElement(children: .contain)
    }
}

#Preview("Rows") {
    VStack(spacing: 12) {
        ReviewCardRow(
            card: TrackedCard(
                catalogCard: CardCatalog.all[0],
                details: CardDetails(
                    balance: 2480.15,
                    minimumPayment: 45,
                    dueDate: DueDate(month: 12, day: 14),
                    apr: 24.99
                )
            ),
            onEdit: {}
        )
        ReviewCardRow(card: TrackedCard(catalogCard: CardCatalog.all[1]), onEdit: {})
    }
    .padding(24)
    .background(Theme.background)
}
