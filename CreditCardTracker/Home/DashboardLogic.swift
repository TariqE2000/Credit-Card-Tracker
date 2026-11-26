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
    /// then by name, so the order never jumps around. Sorted by due date, cards with a missed payment come first.
    func orders(_ first: DashboardCard, before second: DashboardCard) -> Bool {
        switch self {
        case .dueDate:
            if first.isMissed != second.isMissed { return first.isMissed }
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

    /// The due day in the month that starts on `monthStart`. In a month too short for the day, the last day of the month.
    private func dueDay(inMonthStarting monthStart: Date, calendar: Calendar) -> Date? {
        guard let daysInMonth = calendar.range(of: .day, in: .month, for: monthStart)?.count else { return nil }
        return calendar.date(byAdding: .day, value: min(day, daysInMonth) - 1, to: monthStart)
    }

    /// The latest due day before `today`. Today itself does not count, because today's payment is not late yet.
    func previousDue(before today: Date = Date(), calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: today)
        guard let thisMonth = calendar.dateInterval(of: .month, for: start)?.start else { return nil }
        for offset in [0, -1] {
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: thisMonth),
                  let due = dueDay(inMonthStarting: monthStart, calendar: calendar)
            else { return nil }
            if due < start { return due }
        }
        return nil
    }

    /// Every due day after `settled` and before `today`, oldest first. These are the payments that came and went
    /// without being marked as handled: the user's missed payments. Today does not count, because it is not late yet.
    func missedDays(after settled: Date, before today: Date = Date(), calendar: Calendar = .current) -> [Date] {
        let start = calendar.startOfDay(for: today)
        let floor = calendar.startOfDay(for: settled)
        guard floor < start, var monthStart = calendar.dateInterval(of: .month, for: floor)?.start else { return [] }

        var days: [Date] = []
        // Looks at each month from the settled day's month up to this one. The limit is only a safety stop.
        for _ in 0..<600 {
            guard monthStart <= start else { break }
            if let due = dueDay(inMonthStarting: monthStart, calendar: calendar), due > floor, due < start {
                days.append(due)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { break }
            monthStart = next
        }
        return days
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
    /// The due day that was marked as paid, like "Dec 6" when `dueOnText` is "Jan 6". Nil when nothing is marked.
    let paidDueText: String?
    /// The due day after the one above, like "Dec 28" when `dueOnText` is "Nov 28". It is where "Mark paid" moves
    /// the card to. Nil when it cannot be worked out.
    let afterDueText: String?
    /// Due days that passed without being marked as handled, oldest first. Empty for most cards.
    /// One card is always one row: several missed months are listed here, not shown as several cards.
    let missedDueDates: [Date]
    /// The same days as text, like ["Oct 10", "Nov 10"].
    let missedDueTexts: [String]
    /// How many days ago the latest missed due day was. Nil when nothing was missed.
    let missedDaysAgo: Int?

    var id: UUID { card.id }
    /// True when a due day passed without the payment being marked as handled.
    var isMissed: Bool { !missedDueDates.isEmpty }
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

    // MARK: Missed payments

    /// "Missed Nov 20" for one payment, "2 payments missed" for more. Nil when nothing was missed.
    var missedHeadline: String? {
        switch missedDueTexts.count {
        case 0: return nil
        case 1: return "Missed \(missedDueTexts[0])"
        default: return "\(missedDueTexts.count) payments missed"
        }
    }

    /// The gray part after the headline: "6 days ago" for one payment, "since Oct 10" for more.
    var missedTail: String? {
        switch missedDueTexts.count {
        case 0:
            return nil
        case 1:
            guard let ago = missedDaysAgo else { return nil }
            return ago == 1 ? "yesterday" : "\(ago) days ago"
        default:
            return "since \(missedDueTexts[0])"
        }
    }

    /// The red line on a row: "Missed Nov 20 · 6 days ago", or "2 payments missed".
    var missedLineText: String? {
        guard let headline = missedHeadline else { return nil }
        guard missedDueTexts.count == 1, let tail = missedTail else { return headline }
        return "\(headline) · \(tail)"
    }

    /// The days as a sentence: "Nov 20", "Oct 10 and Nov 10", "Sep 10, Oct 10 and Nov 10".
    /// Past four days it gives the range, so the line stays short.
    private var missedList: String {
        let days = missedDueTexts
        switch days.count {
        case 0: return ""
        case 1: return days[0]
        case 2...4: return days.dropLast().joined(separator: ", ") + " and " + days[days.count - 1]
        default: return "\(days[0]) through \(days[days.count - 1])"
        }
    }

    /// The note on the card sheet. It says "may have", because the app cannot see the bank account.
    var missedNotice: String? {
        switch missedDueTexts.count {
        case 0:
            return nil
        case 1:
            return "You may have missed the \(missedDueTexts[0]) payment. If you already paid it, tap Mark paid and this goes away."
        default:
            return "You may have missed \(missedDueTexts.count) payments: \(missedList). If you already paid, tap Mark paid to clear them. Check your statement for the amount you owe."
        }
    }

    /// The line under "Mark paid" on the sheet. Nil when nothing was missed.
    var missedCaption: String? {
        switch missedDueTexts.count {
        case 0:
            return nil
        case 1:
            return "Marks the \(missedDueTexts[0]) payment as paid. Next due: \(dueOnText)."
        case 2:
            return "Marks both missed payments as paid. Next due: \(dueOnText)."
        default:
            return "Marks all \(missedDueTexts.count) missed payments as paid. Next due: \(dueOnText)."
        }
    }

    /// Nil when the card has no complete details, or no due day can be worked out.
    ///
    /// `paidDue` is the due day the user marked as paid. When it is the card's coming due day, that day is
    /// skipped and the card shows the one after it. A paid day that is not the coming one is ignored,
    /// which is how "paid" wears off by itself once the due day has passed.
    ///
    /// `settled` is the latest due day that is dealt with: it was marked paid, or it had already passed when the
    /// card was added. Every due day after it (and after `paidDue`) that is already behind `today` is a missed payment.
    /// Without a `settled` day nothing is flagged.
    init?(_ card: TrackedCard, paidDue: Date? = nil, settled: Date? = nil, today: Date, calendar: Calendar) {
        guard let balance = card.details.balance,
              let minimumPayment = card.details.minimumPayment,
              let dueDate = card.details.dueDate,
              let coming = dueDate.nextDue(onOrAfter: today, calendar: calendar)
        else { return nil }

        var next = coming
        var paid = false
        var paidDay: Date?
        if let paidDue, calendar.isDate(paidDue, inSameDayAs: coming),
           let dayAfter = calendar.date(byAdding: .day, value: 1, to: coming),
           let following = dueDate.nextDue(onOrAfter: dayAfter, calendar: calendar) {
            next = following
            paid = true
            paidDay = coming
        }

        guard let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: next).day
        else { return nil }

        // A due day that is on or before the latest settled or paid day is handled. Later ones that already passed are missed.
        var missed: [Date] = []
        if let handledUpTo = [settled, paidDue].compactMap({ $0 }).max() {
            missed = dueDate.missedDays(after: handledUpTo, before: today, calendar: calendar)
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        self.dueOnText = formatter.string(from: next)
        self.paidDueText = paidDay.map { formatter.string(from: $0) }
        let after = calendar.date(byAdding: .day, value: 1, to: next)
            .flatMap { dueDate.nextDue(onOrAfter: $0, calendar: calendar) }
        self.afterDueText = after.map { formatter.string(from: $0) }
        self.missedDueDates = missed
        self.missedDueTexts = missed.map { formatter.string(from: $0) }
        self.missedDaysAgo = missed.last.flatMap {
            calendar.dateComponents([.day], from: $0, to: calendar.startOfDay(for: today)).day
        }
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
    /// The card due soonest. Cards with a missed payment count by their next due day, like any other card.
    let nextDue: DashboardCard?
    /// Minimum payments of the cards with a missed payment. A card counts once, however many months it missed.
    let missedTotal: Decimal
    /// How many cards have a missed payment.
    let missedCount: Int

    /// `paid` holds, for each card the user marked as paid, the due day that was paid. `settled` holds, for each
    /// card, the latest due day that is dealt with, so later days that passed show as missed.
    init(
        cards tracked: [TrackedCard],
        sortedBy sort: CardSort,
        paid: [UUID: Date] = [:],
        settled: [UUID: Date] = [:],
        today: Date = Date(),
        calendar: Calendar = .current
    ) {
        var complete: [DashboardCard] = []
        var missing: [TrackedCard] = []
        for card in tracked {
            if let item = DashboardCard(card, paidDue: paid[card.id], settled: settled[card.id], today: today, calendar: calendar) {
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
        self.missedTotal = complete.filter(\.isMissed).map(\.minimumPayment).reduce(0, +)
        self.missedCount = complete.filter(\.isMissed).count
        // The card whose next due day is soonest. This does not use the list order, which puts missed cards first.
        self.nextDue = complete.sorted { first, second in
            if first.daysUntilDue != second.daysUntilDue { return first.daysUntilDue < second.daysUntilDue }
            let names = first.card.catalogCard.displayName.localizedCaseInsensitiveCompare(second.card.catalogCard.displayName)
            return names == .orderedAscending
        }.first
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
