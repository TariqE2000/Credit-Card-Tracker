import SwiftUI

/// The Tiles view: every card as a tile, two to a row, in the order picked by the sort button.
struct TilesModeView: View {
    let data: DashboardData
    @Binding var sortName: String
    let onEdit: (UUID) -> Void
    let onPay: (URL) -> Void

    /// What goes in one cell of the grid.
    private enum Item: Identifiable {
        case card(DashboardCard)
        case incomplete(TrackedCard)

        var id: UUID {
            switch self {
            case .card(let item): return item.id
            case .incomplete(let card): return card.id
            }
        }
    }

    /// Cards with details first (in the sort order), then the incomplete ones, cut into rows of two.
    private var rows: [[Item]] {
        let items = data.cards.map(Item.card) + data.incomplete.map(Item.incomplete)
        return stride(from: 0, to: items.count, by: 2).map { start in
            Array(items[start..<min(start + 2, items.count)])
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All cards")
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                SortMenu(sortName: $sortName)
            }

            Grid(horizontalSpacing: 12, verticalSpacing: 12) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(row) { item in
                            tile(for: item)
                        }
                        if row.count == 1 {
                            Color.clear
                        }
                    }
                }
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

    @ViewBuilder
    private func tile(for item: Item) -> some View {
        switch item {
        case .card(let card):
            CardTile(item: card, onEdit: { onEdit(card.id) }, onPay: onPay)
        case .incomplete(let card):
            IncompleteTile(card: card) { onEdit(card.id) }
        }
    }
}

/// One card with details: badge, a chip saying when it is due, name, balance, minimum, due date and Pay.
private struct CardTile: View {
    let item: DashboardCard
    let onEdit: () -> Void
    let onPay: (URL) -> Void

    private var chipText: String {
        if item.isMissed { return "Missed" }
        return item.isPaid ? "Paid" : item.whenText
    }

    private var chipColors: (background: Color, text: Color) {
        if item.isMissed { return (Theme.danger.opacity(0.12), Theme.danger) }
        if item.isPaid { return (Theme.field, Theme.textSecondary) }
        switch item.urgency {
        case .urgent: return (Theme.danger.opacity(0.12), Theme.danger)
        case .soon: return (Theme.accentTint, Theme.accentText)
        case .calm: return (Theme.field, Theme.textSecondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 8) {
                        CardBadge(card: item.card.catalogCard)
                        Spacer(minLength: 4)
                        Text(chipText)
                            .font(.app(12, .semibold))
                            .foregroundStyle(chipColors.text)
                            .lineLimit(1)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(chipColors.background, in: Capsule())
                    }
                    .padding(.bottom, 8)

                    Text(item.card.catalogCard.displayName)
                        .font(.app(15, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)

                    Text(item.balance.usd)
                        .font(.app(20, .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, 2)
                    Text("Min \(item.minimumPayment.usd)")
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                    Text(item.isPaid || item.isMissed ? "Next due \(item.dueOnText)" : "Due \(item.dueOnText)")
                        .font(.app(13))
                        .foregroundStyle(Theme.textSecondary)
                }
                .accessibilityElement(children: .combine)
                .padding(.top, 14)
                .padding(.horizontal, 14)
                .padding(.bottom, item.payURL == nil ? 14 : 0)
            }
            .buttonStyle(RowButtonStyle())
            .accessibilityHint("Opens this card to pay or mark it paid")

            if let url = item.payURL {
                Button { onPay(url) } label: {
                    HStack(spacing: 4) {
                        Text(item.payTitle)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TextLinkButtonStyle(size: 14))
                .accessibilityLabel("\(item.payTitle), \(item.card.catalogCard.displayName)")
                .accessibilityHint("Opens the lender's website or app")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardCardStyle()
    }
}

/// A card missing details: dashed outline, gray badge, and "Add details".
private struct IncompleteTile: View {
    let card: TrackedCard
    let onEdit: () -> Void

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading, spacing: 4) {
                CardBadge(card: card.catalogCard, isMuted: true)
                    .padding(.bottom, 8)

                Text(card.catalogCard.displayName)
                    .font(.app(15, .semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)

                Text("Incomplete · not in your totals")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)

                Text("Add details")
                    .font(.app(14, .semibold))
                    .foregroundStyle(Theme.accentText)
                    .frame(minHeight: 44, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.cornerRadius, style: .continuous)
                    .strokeBorder(
                        Theme.textSecondary.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(RowButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Add the missing details")
    }
}

#Preview("Tiles – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}
