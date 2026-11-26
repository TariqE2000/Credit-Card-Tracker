import Foundation

// MARK: - Sorting

/// How the "All cards" list on the home screen is sorted. The user picks one from the menu above the list.
enum CardSort: String, CaseIterable, Identifiable {
    case dueDate
    case balance
    case minimumPayment
    case bank
    case interestRate

    var id: String { rawValue }

    /// Short name shown on the button above the list, e.g. "Due date".
    var title: String {
        switch self {
        case .dueDate: return "Due date"
        case .balance: return "Balance"
        case .minimumPayment: return "Minimum payment"
        case .bank: return "Bank"
        case .interestRate: return "Interest rate"
        }
    }

    /// Name plus the direction, shown in the menu, e.g. "Due date (soonest first)".
    var menuTitle: String {
        switch self {
        case .dueDate: return "Due date (soonest first)"
        case .balance: return "Balance (biggest first)"
        case .minimumPayment: return "Minimum payment (biggest first)"
        case .bank: return "Bank (A to Z)"
        case .interestRate: return "Interest rate (highest first)"
        }
    }

    /// True when `first` belongs above `second`. Cards that tie on the chosen field go by due date,
    /// then by name, so the order never jumps around.
    func orders(_ first: DashboardCard, before second: DashboardCard) -> Bool {
        switch self {
        case .dueDate:
            break
        case .balance:
            if first.balance != second.balance { return first.balance > second.balance }
        case .minimumPayment:
            if first.minimumPayment != second.minimumPayment { return first.minimumPayment > second.minimumPayment }
        case .bank:
            let order = first.card.catalogCard.issuer.localizedCaseInsensitiveCompare(second.card.catalogCard.issuer)
            if order != .orderedSame { return order == .orderedAscending }
        case .interestRate:
            // Cards with no APR go last.
            switch (first.apr, second.apr) {
            case let (a?, b?):
                if a != b { return a > b }
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                break
            }
        }

        if first.daysUntilDue != second.daysUntilDue { return first.daysUntilDue < second.daysUntilDue }
        let names = first.card.catalogCard.displayName.localizedCaseInsensitiveCompare(second.card.catalogCard.displayName)
        return names == .orderedAscending
    }
}

// MARK: - Due dates

extension DueDate {
    /// The next day this payment is due, on or after `today`. A due date repeats every month, so
    /// only the day of the month counts: a card entered as "Dec 14" is due on the 14th of every month.
    /// In a month too short for that day (the 31st in April) the last day of the month is used.
    func nextDue(onOrAfter today: Date = Date(), calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: today)
        guard let thisMonth = calendar.dateInterval(of: .month, for: start)?.start else { return nil }
        // This month's due day if it has not passed yet, otherwise next month's.
        for offset in 0...1 {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: thisMonth),
                  let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count,
                  let due = calendar.date(byAdding: .day, value: min(day, daysInMonth) - 1, to: monthStart)
            else { return nil }
            if due >= start { return due }
        }
        return nil
    }

    /// How many days from `today` until the next due day. 0 means due today.
    func daysUntil(from today: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let next = nextDue(onOrAfter: today, calendar: calendar) else { return nil }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: next).day
    }
}

/// How close a due date is. Sets the color of the "in 2 days" text.
enum DueUrgency {
    /// Due today, tomorrow or the day after: red.
    case urgent
    /// Due within the week: purple.
    case soon
    /// Further away: gray.
    case calm

    init(daysUntilDue: Int) {
        if daysUntilDue <= 2 {
            self = .urgent
        } else if daysUntilDue <= DashboardData.dueSoonDays {
            self = .soon
        } else {
            self = .calm
        }
    }
}

// MARK: - What the screen shows

/// A card with every detail filled in, plus how many days are left until it is due.
struct DashboardCard: Identifiable, Hashable {
    let card: TrackedCard
    let balance: Decimal
    let minimumPayment: Decimal
    let dueDate: DueDate
    /// The next day it is due, like "Nov 28". The month is worked out from today, not taken from
    /// what the user typed, because the due day repeats every month.
    let dueOnText: String
    let daysUntilDue: Int
    /// The day this card is due next, as a date. If this month's payment is marked paid, it is next month's.
    let nextDueDate: Date
    /// True when this month's payment was marked paid. The due date above is then the one after it.
    let isPaid: Bool

    var id: UUID { card.id }
    /// The bank's page to open from the Pay button. Nil when there is no link for the bank, or the
    /// payment is already marked paid.
    var payURL: URL? { isPaid ? nil : PayLinks.url(for: card.catalogCard) }
    /// "Pay Chase": the lender this card is paid to, which is also the lender the link opens.
    var payTitle: String { PayLinks.buttonTitle(for: card.catalogCard) }
    var apr: Decimal? { card.details.apr }
    var urgency: DueUrgency { DueUrgency(daysUntilDue: daysUntilDue) }

    /// "today", "tomorrow" or "in 5 days"
    var whenText: String {
        switch daysUntilDue {
        case 0: return "today"
        case 1: return "tomorrow"
        default: return "in \(daysUntilDue) days"
        }
    }

    /// "Due today", "Due tomorrow" or "Due in 5 days"
    var dueChipText: String {
        "Due \(whenText)"
    }

    /// Nil when the card has no complete details, or no due day can be worked out.
    ///
    /// `paidDue` is the due day the user marked as paid. When it is the card's coming due day, that day is
    /// skipped and the card shows the one after it. A paid day that is not the coming one is ignored,
    /// which is how "paid" wears off by itself once the due day has passed.
    init?(_ card: TrackedCard, paidDue: Date? = nil, today: Date, calendar: Calendar) {
        guard let balance = card.details.balance,
              let minimumPayment = card.details.minimumPayment,
              let dueDate = card.details.dueDate,
              let coming = dueDate.nextDue(onOrAfter: today, calendar: calendar)
        else { return nil }

        var next = coming
        var paid = false
        if let paidDue, calendar.isDate(paidDue, inSameDayAs: coming),
           let dayAfter = calendar.date(byAdding: .day, value: 1, to: coming),
           let following = dueDate.nextDue(onOrAfter: dayAfter, calendar: calendar) {
            next = following
            paid = true
        }

        guard let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: next).day
        else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        self.dueOnText = formatter.string(from: next)
        self.card = card
        self.balance = balance
        self.minimumPayment = minimumPayment
        self.dueDate = dueDate
        self.daysUntilDue = days
        self.nextDueDate = next
        self.isPaid = paid
    }
}

/// Everything the home screen shows, worked out from the user's cards. Pure data, so it can be tested.
struct DashboardData {
    /// "Due in 7 days" on the screen counts cards due today up to this many days from now.
    static let dueSoonDays = 7

    /// Cards with complete details, in the order the user picked.
    let cards: [DashboardCard]
    /// Cards missing a detail. Always shown last, and left out of every total.
    let incomplete: [TrackedCard]

    let totalBalance: Decimal
    let totalMinimums: Decimal
    /// Minimum payments due within `dueSoonDays` days.
    let dueSoonTotal: Decimal
    /// The card due soonest.
    let nextDue: DashboardCard?

    /// `paid` holds, for each card the user marked as paid, the due day that was paid.
    init(
        cards tracked: [TrackedCard],
        sortedBy sort: CardSort,
        paid: [UUID: Date] = [:],
        today: Date = Date(),
        calendar: Calendar = .current
    ) {
        var complete: [DashboardCard] = []
        var missing: [TrackedCard] = []
        for card in tracked {
            if let item = DashboardCard(card, paidDue: paid[card.id], today: today, calendar: calendar) {
                complete.append(item)
            } else {
                missing.append(card)
            }
        }

        self.cards = complete.sorted { sort.orders($0, before: $1) }
        self.incomplete = missing
        self.totalBalance = complete.map(\.balance).reduce(0, +)
        self.totalMinimums = complete.map(\.minimumPayment).reduce(0, +)
        self.dueSoonTotal = complete
            .filter { $0.daysUntilDue <= Self.dueSoonDays }
            .map(\.minimumPayment)
            .reduce(0, +)
        self.nextDue = complete.sorted { CardSort.dueDate.orders($0, before: $1) }.first
    }

    /// The card shown in the banner above the list: the next card due, if it is due within the week.
    var dueSoon: DashboardCard? {
        guard let nextDue, nextDue.daysUntilDue <= Self.dueSoonDays else { return nil }
        return nextDue
    }
}

extension Decimal {
    /// "$2,480.15"
    var usd: String {
        formatted(.currency(code: "USD"))
    }
}
