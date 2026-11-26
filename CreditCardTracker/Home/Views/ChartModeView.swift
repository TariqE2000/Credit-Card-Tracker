import SwiftUI

/// The Chart view: one bar per card, biggest balance first, with each card's share of the total.
/// "View as a table" shows the same numbers as text.
struct ChartModeView: View {
    let data: DashboardData

    @State private var showsTable = false

    var body: some View {
        let bars = BalanceBar.bars(from: data.cards)

        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Balance by card")
                    .font(.app(18, .bold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("Biggest first")
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            if bars.isEmpty {
                Text("Add a balance to a card to see it here.")
                    .font(.app(15))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            } else {
                if showsTable {
                    table(bars)
                } else {
                    chart(bars)
                }

                Button {
                    showsTable.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: showsTable ? "chart.bar" : "tablecells")
                            .font(.system(size: 14, weight: .medium))
                        Text(showsTable ? "View as a chart" : "View as a table")
                    }
                    .frame(minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(TextLinkButtonStyle(size: 14))
            }

            if !data.incomplete.isEmpty {
                Text(incompleteNote)
                    .font(.app(12))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var incompleteNote: String {
        data.incomplete.count == 1
            ? "\(data.incomplete[0].catalogCard.displayName) is left out because its details are incomplete."
            : "\(data.incomplete.count) cards are left out because their details are incomplete."
    }

    // MARK: Chart

    private func chart(_ bars: [BalanceBar]) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Each bar is one card's balance. The percent is its share of your \(data.totalBalance.usd) total.")
                .font(.app(12))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(bars) { bar in
                    BarRow(bar: bar)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dashboardCardStyle()
    }

    // MARK: Table

    private func table(_ bars: [BalanceBar]) -> some View {
        VStack(spacing: 0) {
            tableRow("Card", "Balance", "Share", isHeader: true)
            ForEach(bars) { bar in
                Theme.border.frame(height: 1)
                tableRow(bar.card.card.catalogCard.displayName, bar.balance.usd, bar.shareText, isHeader: false)
            }
            Theme.border.frame(height: 1)
            tableRow("Total", data.totalBalance.usd, "100.0%", isHeader: true)
        }
        .dashboardCardStyle()
    }

    private func tableRow(_ name: String, _ balance: String, _ share: String, isHeader: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(name)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(balance)
                .frame(minWidth: 86, alignment: .trailing)
            Text(share)
                .frame(minWidth: 52, alignment: .trailing)
        }
        .font(.app(14, isHeader ? .semibold : .regular))
        .foregroundStyle(Theme.textPrimary)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// One bar: the card's name and share on top, then the bar with its balance at the tip.
private struct BarRow: View {
    let bar: BalanceBar

    /// Room kept to the right of the longest bar for its balance, like "$2,480.15".
    private static let valueWidth: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(bar.card.card.catalogCard.displayName)
                    .font(.app(14, .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Text(bar.shareText)
                    .font(.app(13))
                    .foregroundStyle(Theme.textSecondary)
            }

            GeometryReader { proxy in
                let longest = max(proxy.size.width - Self.valueWidth, 0)
                HStack(spacing: 8) {
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 0,
                        bottomTrailingRadius: 4,
                        topTrailingRadius: 4
                    )
                    .fill(Theme.accent)
                    .frame(width: max(longest * bar.fraction, 2), height: 16)

                    Text(bar.balance.usd)
                        .font(.app(14, .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .fixedSize()

                    Spacer(minLength: 0)
                }
                .frame(height: proxy.size.height)
            }
            .frame(height: 20)
            .overlay(alignment: .leading) {
                Theme.border.frame(width: 1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(bar.card.card.catalogCard.displayName), \(bar.balance.usd), \(bar.shareText) of your total balance"
        )
    }
}

#Preview("Chart – light") {
    NavigationStack {
        ViewsPage()
    }
    .environmentObject(viewsPreviewStore())
    .preferredColorScheme(.light)
}
