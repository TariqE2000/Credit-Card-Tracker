import Foundation

/// A month and day, like "Dec 14". The year does not matter because a card's due date repeats every month.
struct DueDate: Hashable {
    let month: Int
    let day: Int

    private static let daysInMonth = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

    init?(month: Int, day: Int) {
        guard (1...12).contains(month), (1...Self.daysInMonth[month - 1]).contains(day) else {
            return nil
        }
        self.month = month
        self.day = day
    }

    /// Reads four typed digits such as "1214" as December 14.
    init?(digits: String) {
        guard digits.count == 4, digits.allSatisfy({ $0.isASCII && $0.isNumber }), let value = Int(digits) else {
            return nil
        }
        self.init(month: value / 100, day: value % 100)
    }

    /// The four typed digits for this date, e.g. "1214". Used to fill the form field.
    var digits: String {
        String(format: "%02d%02d", month, day)
    }

    /// Takes the month and day from a date picked in the calendar. The year is dropped.
    init?(date: Date, calendar: Calendar = .current) {
        let parts = calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day else { return nil }
        self.init(month: month, day: day)
    }

    /// The first day on or after `reference` that falls on this month and day. The calendar opens
    /// on this date. Feb 29 waits for the next leap year. Nil only if no such day is found.
    func nextOccurrence(onOrAfter reference: Date = Date(), calendar: Calendar = .current) -> Date? {
        let start = calendar.startOfDay(for: reference)
        let firstYear = calendar.component(.year, from: start)
        // Eight years is always enough to reach the next Feb 29.
        for year in firstYear...(firstYear + 8) {
            let parts = DateComponents(year: year, month: month, day: day)
            guard let date = calendar.date(from: parts),
                  calendar.component(.month, from: date) == month,
                  calendar.component(.day, from: date) == day,
                  date >= start
            else { continue }
            return date
        }
        return nil
    }

    /// "Dec 14"
    var shortDescription: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        return "\(formatter.shortMonthSymbols[month - 1]) \(day)"
    }
}

/// What the user can fill in for a card. Every field is optional.
struct CardDetails: Hashable {
    var balance: Decimal?
    var minimumPayment: Decimal?
    var dueDate: DueDate?
    /// Interest rate as a percent, e.g. 24.99. Optional even for a "complete" card.
    var apr: Decimal?

    /// The "details complete" flag: balance, minimum payment and due date are all filled in.
    /// APR is not required.
    var isComplete: Bool {
        balance != nil && minimumPayment != nil && dueDate != nil
    }
}

/// A card the user picked, together with whatever details they entered.
struct TrackedCard: Identifiable, Hashable {
    let id: UUID
    /// Changes only for a not-listed card, when the user types its name.
    var catalogCard: Issuer
    var details: CardDetails

    init(id: UUID = UUID(), catalogCard: Issuer, details: CardDetails = CardDetails()) {
        self.id = id
        self.catalogCard = catalogCard
        self.details = details
    }

    var detailsComplete: Bool { details.isComplete }
}

extension Collection where Element == TrackedCard {
    /// Sum of balances. Cards without complete details are left out, matching the note on the review screen.
    var totalBalance: Decimal {
        filter(\.detailsComplete).compactMap(\.details.balance).reduce(0, +)
    }
}
