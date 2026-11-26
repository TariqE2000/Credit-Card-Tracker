import Foundation

// MARK: - By bank

/// The cards of one bank, for the By bank view: how many, their total balance and minimum, and the bank's
/// Pay link when it has one.
struct BankGroup: Identifiable {
    /// What cards are grouped by: the bank's ID from the card list, or its name for a card typed in by hand.
    let key: String
    /// "Chase", "Capital One".
    let name: String
    /// Soonest due first.
    let cards: [DashboardCard]

    var id: String { key }
    var totalBalance: Decimal { cards.map(\.balance).reduce(0, +) }
    var totalMinimums: Decimal { cards.map(\.minimumPayment).reduce(0, +) }
    /// The lender to pay, when the bank is in the Pay list.
    var payBank: PayLinks.Bank? {
        cards.lazy.compactMap { PayLinks.bank(for: $0.card.catalogCard) }.first
    }

    /// Groups the cards by bank. The bank due soonest comes first, and the cards inside a group go
    /// soonest first. Cards that tie go by name so the order never jumps around.
    static func groups(from cards: [DashboardCard]) -> [BankGroup] {
        func key(for card: DashboardCard) -> String {
            let catalog = card.card.catalogCard
            if let issuerID = catalog.issuerID { return "id:" + issuerID }
            return "name:" + catalog.issuer.lowercased()
        }
        func name(_ card: DashboardCard) -> String { card.card.catalogCard.displayName }
        func ordered(_ a: DashboardCard, _ b: DashboardCard) -> Bool {
            if a.daysUntilDue != b.daysUntilDue { return a.daysUntilDue < b.daysUntilDue }
            return name(a).localizedCaseInsensitiveCompare(name(b)) == .orderedAscending
        }

        let grouped = Dictionary(grouping: cards, by: key(for:))
        let built = grouped.map { key, members -> BankGroup in
            let sorted = members.sorted(by: ordered)
            return BankGroup(key: key, name: sorted[0].card.catalogCard.issuer, cards: sorted)
        }
        return built.sorted { a, b in
            if let first = a.cards.first, let second = b.cards.first, first.daysUntilDue != second.daysUntilDue {
                return first.daysUntilDue < second.daysUntilDue
            }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }
}

// MARK: - By week

/// One week of the By week view: the cards due that week and what their minimums add up to.
struct WeekSection: Identifiable {
    /// The first day of the week.
    let start: Date
    /// The last day of the week.
    let end: Date
    /// "This week", "Next week", or the dates, like "Dec 6 – Dec 12".
    let title: String
    /// The dates under "This week" and "Next week", like "Nov 22 – Nov 28". Nil for the other weeks,
    /// whose title already is the dates.
    let dates: String?
    /// Soonest due first.
    let cards: [DashboardCard]

    var id: Date { start }
    var totalMinimums: Decimal { cards.map(\.minimumPayment).reduce(0, +) }

    /// Cuts the cards into weeks by the day each is due next. Only weeks with a card are returned,
    /// in date order. A week starts on the calendar's first weekday (Sunday in the US).
    static func sections(from cards: [DashboardCard], today: Date = Date(), calendar: Calendar = .current) -> [WeekSection] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"

        let byWeek = Dictionary(grouping: cards) { card -> Date in
            calendar.dateInterval(of: .weekOfYear, for: card.nextDueDate)?.start ?? card.nextDueDate
        }

        return byWeek.keys.sorted().compactMap { start -> WeekSection? in
            guard let members = byWeek[start],
                  let end = calendar.date(byAdding: .day, value: 6, to: start)
            else { return nil }

            let range = "\(formatter.string(from: start)) – \(formatter.string(from: end))"
            let weeksAway = (calendar.dateComponents([.day], from: thisWeek.start, to: start).day ?? 0) / 7
            let title: String
            let dates: String?
            switch weeksAway {
            case 0:
                title = "This week"
                dates = range
            case 1:
                title = "Next week"
                dates = range
            default:
                title = range
                dates = nil
            }

            let sorted = members.sorted { a, b in
                if a.nextDueDate != b.nextDueDate { return a.nextDueDate < b.nextDueDate }
                return a.card.catalogCard.displayName.localizedCaseInsensitiveCompare(b.card.catalogCard.displayName)
                    == .orderedAscending
            }
            return WeekSection(start: start, end: end, title: title, dates: dates, cards: sorted)
        }
    }
}
