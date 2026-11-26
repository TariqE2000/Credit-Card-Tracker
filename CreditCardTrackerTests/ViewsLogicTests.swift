import XCTest
@testable import CreditCardTracker

/// The numbers behind the Views page. "Today" is Thursday Nov 26, 2026 unless a test says otherwise.
final class ViewsLogicTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        calendar.firstWeekday = 1
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var today: Date { day(2026, 11, 26) }

    private func amount(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US"))!
    }

    private func card(_ name: String, due: (month: Int, day: Int), minimum: String = "25") -> TrackedCard {
        TrackedCard(
            catalogCard: CatalogCard(id: "test-\(name)", name: name, issuer: "Bank", badgeCode: "XX", badgeColorHex: 0),
            details: CardDetails(
                balance: amount("100"),
                minimumPayment: amount(minimum),
                dueDate: DueDate(month: due.month, day: due.day),
                apr: nil
            )
        )
    }

    /// The five cards from the design, due on the 28th, 3rd, 6th, 9th and 14th of every month.
    private var sampleCards: [DashboardCard] {
        let tracked = [
            card("Chase Sapphire Preferred", due: (11, 28), minimum: "75"),
            card("Capital One Quicksilver", due: (12, 3), minimum: "35"),
            card("Chase Freedom Unlimited", due: (12, 6), minimum: "35"),
            card("Apple Card", due: (12, 9), minimum: "25"),
            card("Citi Double Cash", due: (12, 14), minimum: "60"),
        ]
        return DashboardData(cards: tracked, sortedBy: .dueDate, today: today, calendar: calendar).cards
    }

    private func november(_ cards: [DashboardCard]? = nil) throws -> CalendarMonth {
        try XCTUnwrap(CalendarMonth(cards: cards ?? sampleCards, month: today, calendar: calendar))
    }

    // MARK: Calendar

    func testNovember2026() throws {
        let month = try november()
        XCTAssertEqual(month.title, "November 2026")
        XCTAssertEqual(month.days.count, 30)
        // Nov 1, 2026 is a Sunday, so the 1st sits in the first column.
        XCTAssertEqual(month.leadingBlanks, 0)
    }

    func testCardsLandOnTheirDueDay() throws {
        let month = try november()
        let dueDays = month.days.filter { !$0.cards.isEmpty }.map(\.number)
        XCTAssertEqual(dueDays, [3, 6, 9, 14, 28])
        XCTAssertEqual(month.days[27].cards.map(\.card.catalogCard.name), ["Chase Sapphire Preferred"])
    }

    func testDueDatesRepeatEveryMonth() throws {
        // The cards were typed with November and December dates. They show in January too.
        let january = try XCTUnwrap(CalendarMonth(cards: sampleCards, month: day(2027, 1, 10), calendar: calendar))
        XCTAssertEqual(january.title, "January 2027")
        XCTAssertEqual(january.days.filter { !$0.cards.isEmpty }.map(\.number), [3, 6, 9, 14, 28])
        // Jan 1, 2027 is a Friday: five empty cells before it.
        XCTAssertEqual(january.leadingBlanks, 5)
    }

    func testADueDayThatDoesNotExistLandsOnTheLastDay() throws {
        let tracked = [
            card("Thirty-first", due: (1, 31)),
            card("Thirtieth", due: (1, 30)),
            card("Twenty-ninth", due: (1, 29)),
        ]
        let cards = DashboardData(cards: tracked, sortedBy: .dueDate, today: today, calendar: calendar).cards

        // February 2027 has 28 days.
        let february = try XCTUnwrap(CalendarMonth(cards: cards, month: day(2027, 2, 5), calendar: calendar))
        XCTAssertEqual(february.days.count, 28)
        XCTAssertEqual(february.days.last?.cards.count, 3)
        XCTAssertEqual(february.leadingBlanks, 1)

        // November has 30 days: the 31st moves to the 30th, which already has the card due on the 30th.
        let november = try XCTUnwrap(CalendarMonth(cards: cards, month: today, calendar: calendar))
        XCTAssertEqual(november.days.last?.cards.map(\.card.catalogCard.name).sorted(), ["Thirtieth", "Thirty-first"])
        XCTAssertEqual(november.days[28].cards.map(\.card.catalogCard.name), ["Twenty-ninth"])
    }

    func testCardsOnTheSameDayAreSortedByName() throws {
        let tracked = [card("Zeta", due: (11, 10)), card("Alpha", due: (11, 10)), card("Mid", due: (11, 10))]
        let cards = DashboardData(cards: tracked, sortedBy: .dueDate, today: today, calendar: calendar).cards
        let month = try november(cards)
        XCTAssertEqual(month.days[9].cards.map(\.card.catalogCard.name), ["Alpha", "Mid", "Zeta"])
    }

    func testStillAheadThisMonthCountsFromTodayOn() throws {
        let month = try november()
        let ahead = month.due(onOrAfter: today, calendar: calendar)
        XCTAssertEqual(ahead.minimums, amount("75"))
        XCTAssertEqual(ahead.cardCount, 1)
    }

    func testACardDueTodayIsStillAhead() throws {
        let cards = DashboardData(cards: [card("Today", due: (11, 26))], sortedBy: .dueDate, today: today, calendar: calendar).cards
        let ahead = try november(cards).due(onOrAfter: today, calendar: calendar)
        XCTAssertEqual(ahead.cardCount, 1)
    }

    func testWholeMonthTotalMatchesTheMinimumsTotal() throws {
        let all = try november().dueAllMonth
        XCTAssertEqual(all.minimums, amount("230"))
        XCTAssertEqual(all.cardCount, 5)
    }

    func testWeekdayLettersFollowTheFirstDayOfTheWeek() {
        XCTAssertEqual(CalendarMonth.weekdayLetters(calendar: calendar), ["S", "M", "T", "W", "T", "F", "S"])
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        XCTAssertEqual(CalendarMonth.weekdayLetters(calendar: mondayFirst), ["M", "T", "W", "T", "F", "S", "S"])
    }

    func testBlanksFollowTheFirstDayOfTheWeek() throws {
        var mondayFirst = calendar
        mondayFirst.firstWeekday = 2
        // Nov 1, 2026 is a Sunday: six cells before it when the week starts on Monday.
        let month = try XCTUnwrap(CalendarMonth(cards: [], month: today, calendar: mondayFirst))
        XCTAssertEqual(month.leadingBlanks, 6)
    }

    // MARK: Wording

    func testDueWording() {
        XCTAssertEqual(DueWording.text(daysAway: 0), "today")
        XCTAssertEqual(DueWording.text(daysAway: 1), "tomorrow")
        XCTAssertEqual(DueWording.text(daysAway: 5), "in 5 days")
        XCTAssertEqual(DueWording.text(daysAway: -1), "yesterday")
        XCTAssertEqual(DueWording.text(daysAway: -20), "20 days ago")
    }
}
