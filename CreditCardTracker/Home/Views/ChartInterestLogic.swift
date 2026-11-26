import Foundation

extension Decimal {
    /// Rounded to `places` decimal places, halves rounding up: 27.7677 to 27.77.
    func rounded(toPlaces places: Int) -> Decimal {
        var value = self
        var result = Decimal()
        NSDecimalRound(&result, &value, places, .plain)
        return result
    }

    /// As a Double, for drawing. Not for money.
    var asDouble: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}

// MARK: - Chart

/// One bar of the Chart view: a card's balance and its share of the total.
struct BalanceBar: Identifiable {
    let card: DashboardCard
    /// Percent of the total balance, to one decimal place: 35.5.
    let share: Decimal
    /// How long the bar is, from 0 to 1. The biggest balance is 1.
    let fraction: Double

    var id: UUID { card.id }
    var balance: Decimal { card.balance }

    /// "35.5%"
    var shareText: String {
        String(format: "%.1f%%", share.asDouble)
    }

    /// One bar per card with details, biggest balance first. Ties go by name.
    static func bars(from cards: [DashboardCard]) -> [BalanceBar] {
        let sorted = cards.sorted { a, b in
            if a.balance != b.balance { return a.balance > b.balance }
            return a.card.catalogCard.displayName.localizedCaseInsensitiveCompare(b.card.catalogCard.displayName)
                == .orderedAscending
        }
        let total = sorted.map(\.balance).reduce(0, +)
        let biggest = sorted.first?.balance ?? 0

        return sorted.map { card in
            let share: Decimal = total > 0 ? (card.balance / total * 100).rounded(toPlaces: 1) : 0
            let fraction: Double = biggest > 0 ? (card.balance / biggest).asDouble : 0
            return BalanceBar(card: card, share: share, fraction: fraction)
        }
    }
}

// MARK: - Interest

/// One row of the Interest view: a card, its interest rate, and about what a month of interest costs.
struct InterestRow: Identifiable {
    let card: DashboardCard
    /// Yearly interest rate as a percent, like 24.99. Nil when the user has not added one.
    let apr: Decimal?
    /// Balance times the rate, divided by 12, to the cent. Nil without a rate.
    let monthlyInterest: Decimal?

    var id: UUID { card.id }

    /// "24.99%"
    var aprText: String? {
        apr.map { String(format: "%.2f%%", $0.asDouble) }
    }
}

/// The Interest view's rows and the estimate at the top.
struct InterestSummary {
    /// Highest rate first. Cards without a rate go last.
    let rows: [InterestRow]
    /// About what a month of interest costs across the cards that have a rate.
    let monthlyTotal: Decimal
    /// How many cards the estimate adds up.
    let countedCards: Int

    var totalCards: Int { rows.count }
    var cardsWithoutAPR: [InterestRow] { rows.filter { $0.apr == nil } }

    /// "Adds up 4 of 5 cards. Citi Double Cash has no APR yet."
    var note: String {
        let missing = cardsWithoutAPR
        switch missing.count {
        case 0:
            return totalCards == 1 ? "Adds up your 1 card." : "Adds up all \(totalCards) cards."
        case 1:
            return "Adds up \(countedCards) of \(totalCards) cards. \(missing[0].card.card.catalogCard.displayName) has no APR yet."
        default:
            return "Adds up \(countedCards) of \(totalCards) cards. \(missing.count) cards have no APR yet."
        }
    }

    init(cards: [DashboardCard]) {
        let built = cards.map { card -> InterestRow in
            guard let apr = card.apr else { return InterestRow(card: card, apr: nil, monthlyInterest: nil) }
            let monthly = (card.balance * apr / 100 / 12).rounded(toPlaces: 2)
            return InterestRow(card: card, apr: apr, monthlyInterest: monthly)
        }

        rows = built.sorted { a, b in
            switch (a.apr, b.apr) {
            case let (x?, y?):
                if x != y { return x > y }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
            if a.card.balance != b.card.balance { return a.card.balance > b.card.balance }
            return a.card.card.catalogCard.displayName.localizedCaseInsensitiveCompare(b.card.card.catalogCard.displayName)
                == .orderedAscending
        }
        monthlyTotal = built.compactMap(\.monthlyInterest).reduce(0, +)
        countedCards = built.filter { $0.apr != nil }.count
    }
}
