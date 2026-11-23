import SwiftUI

/// One card on the review screen. Cards with complete details show balance, minimum and due date;
/// cards without them show a dashed "Incomplete" row with an "Add details" link.
struct ReviewCardRow: View {
    let card: TrackedCard
    /// The card's name on screen: its issuer, numbered when the user has several cards from it ("Chase 2").
    let title: String
    let onEdit: () -> Void

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
                CardBadge(issuer: card.issuer)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.app(16, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    if let aprText {
                        Text(aprText)
                            .font(.app(13))
                            .foregroundStyle(Theme.textSecondary)
                    }
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

    /// "24.99% APR", or nil when no APR was entered.
    private var aprText: String? {
        card.details.apr.map { "\(FormInput.text(for: $0))% APR" }
    }

    private static func money(_ value: Decimal?) -> String {
        guard let value else { return "–" }
        return value.formatted(.currency(code: "USD"))
    }

    // MARK: Incomplete

    private var incompleteRow: some View {
        HStack(spacing: 14) {
            CardBadge(issuer: card.issuer, isMuted: true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
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
                issuer: BuiltInIssuers.all[0],
                details: CardDetails(
                    balance: 2480.15,
                    minimumPayment: 45,
                    dueDate: DueDate(month: 12, day: 14),
                    apr: 24.99
                )
            ),
            title: "Chase 1",
            onEdit: {}
        )
        ReviewCardRow(card: TrackedCard(issuer: BuiltInIssuers.all[0]), title: "Chase 2", onEdit: {})
    }
    .padding(24)
    .background(Theme.background)
}
