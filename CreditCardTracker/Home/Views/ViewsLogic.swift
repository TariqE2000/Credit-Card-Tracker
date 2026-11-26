import Foundation

// MARK: - Wording

/// How far away a due day is, in words: "today", "tomorrow", "in 3 days", "2 days ago".
enum DueWording {
    static func text(daysAway days: Int) -> String {
        switch days {
        case 0: return "today"
        case 1: return "tomorrow"
        case -1: return "yesterday"
        case ..<0: return "\(-days) days ago"
        default: return "in \(days) days"
        }
    }
}

// MARK: - Calendar

/// One month for the Calendar view: which cards are due on which day.
///
/// Due dates repeat every month, so a card due on the 28th is on the 28th of every month, not only the
/// month the user typed. A card due on the 31st is shown on the last day of a shorter month.
struct CalendarMonth {
    struct Day: Identifiable {
        /// Day of the month, 1 to 31.
        let number: Int
        let date: Date
        /// Cards due on this day, by name.
        let cards: [DashboardCard]

        var id: Int { number }
    }

    /// The first day of the month.
    let monthStart: Date
    /// "November 2026"
    let title: String
    /// Empty cells before the 1st, so the 1st lands under the right weekday.
    let leadingBlanks: Int
    let days: [Day]

    /// Nil only if the calendar cannot work out the month.
    init?(cards: [DashboardCard], month: Date, calendar: Calendar = .current) {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let dayCount = calendar.range(of: .day, in: .month, for: interval.start)?.count
        else { return nil }

        let start = interval.start
        let weekday = calendar.component(.weekday, from: start)

        var built: [Day] = []
        for number in 1...dayCount {
            guard let date = calendar.date(byAdding: .day, value: number - 1, to: start) else { return nil }
            let due = cards
                .filter { min($0.dueDate.day, dayCount) == number }
                .sorted {
                    $0.card.catalogCard.displayName.localizedCaseInsensitiveCompare($1.card.catalogCard.displayName)
                        == .orderedAscending
                }
            built.append(Day(number: number, date: date, cards: due))
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "LLLL yyyy"

        self.monthStart = start
        self.title = formatter.string(from: start)
        self.leadingBlanks = (weekday - calendar.firstWeekday + 7) % 7
        self.days = built
    }

    /// The minimum payments due on or after `today` this month, and how many cards that is.
    func due(onOrAfter today: Date, calendar: Calendar = .current) -> (minimums: Decimal, cardCount: Int) {
        let start = calendar.startOfDay(for: today)
        let cards = days.filter { $0.date >= start }.flatMap(\.cards)
        return (cards.map(\.minimumPayment).reduce(0, +), cards.count)
    }

    /// Every minimum payment in the month, and how many cards that is.
    var dueAllMonth: (minimums: Decimal, cardCount: Int) {
        let cards = days.flatMap(\.cards)
        return (cards.map(\.minimumPayment).reduce(0, +), cards.count)
    }

    /// The first letters of the weekdays in the order the calendar starts them: S M T W T F S.
    static func weekdayLetters(calendar: Calendar = .current) -> [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...]) + Array(symbols[..<shift])
    }
}
