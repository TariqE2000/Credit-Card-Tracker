import XCTest
@testable import CreditCardTracker

/// The By bank and By week views. "Today" is Thursday Nov 26, 2026 unless a test says otherwise.
final class BankWeekLogicTests: XCTestCase {
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

    private func card(
        _ name: String,
        issuer: String,
        issuerID: String? = nil,
        balance: String,
        minimum: String,
        due: (month: Int, day: Int)
    ) -> TrackedCard {
        TrackedCard(
            catalogCard: CatalogCard(
                id: "test-\(name)", name: name, issuer: issuer, badgeCode: "XX", badgeColorHex: 0, issuerID: issuerID
            ),
            details: CardDetails(
                balance: amount(balance),
                minimumPayment: amount(minimum),
                dueDate: DueDate(month: due.month, day: due.day),
                apr: nil
            )
        )
    }

    /// The five cards from the design.
    private var tracked: [TrackedCard] {
        [
            card("Chase Sapphire Preferred", issuer: "Chase", issuerID: "chase", balance: "2480.15", minimum: "75", due: (11, 28)),
            card("Capital One Quicksilver", issuer: "Capital One", issuerID: "capital-one", balance: "1120.40", minimum: "35", due: (12, 3)),
            card("Chase Freedom Unlimited", issuer: "Chase", issuerID: "chase", balance: "860.00", minimum: "35", due: (12, 6)),
            card("Apple Card", issuer: "Apple", balance: "640.00", minimum: "25", due: (12, 9)),
            card("Citi Double Cash", issuer: "Citi", issuerID: "citi", balance: "1890.22", minimum: "60", due: (12, 14)),
        ]
    }

    private func dashboardCards(_ cards: [TrackedCard]? = nil, paid: [UUID: Date] = [:]) -> [DashboardCard] {
        DashboardData(cards: cards ?? tracked, sortedBy: .dueDate, paid: paid, today: today, calendar: calendar).cards
    }

    // MARK: By bank

    func testCardsAreGroupedByBankSoonestDueFirst() {
        let groups = BankGroup.groups(from: dashboardCards())
        XCTAssertEqual(groups.map(\.name), ["Chase", "Capital One", "Apple", "Citi"])
        XCTAssertEqual(groups.map(\.cards.count), [2, 1, 1, 1])
    }

    func testTheCardsInsideABankGoSoonestFirst() {
        let chase = BankGroup.groups(from: dashboardCards())[0]
        XCTAssertEqual(chase.cards.map(\.card.catalogCard.name), ["Chase Sapphire Preferred", "Chase Freedom Unlimited"])
    }

    func testABankAddsUpItsBalancesAndMinimums() {
        let chase = BankGroup.groups(from: dashboardCards())[0]
        XCTAssertEqual(chase.totalBalance, amount("3340.15"))
        XCTAssertEqual(chase.totalMinimums, amount("110"))
    }

    func testGroupTotalsMatchTheWholeList() {
        let groups = BankGroup.groups(from: dashboardCards())
        XCTAssertEqual(groups.map(\.totalBalance).reduce(0, +), amount("6990.77"))
        XCTAssertEqual(groups.map(\.totalMinimums).reduce(0, +), amount("230"))
    }

    func testABanksPayLinkIsItsOwnLender() {
        let groups = BankGroup.groups(from: dashboardCards())
        XCTAssertEqual(groups[0].payBank?.buttonTitle, "Pay Chase")
        XCTAssertEqual(groups[1].payBank?.buttonTitle, "Pay Capital One")
        XCTAssertNil(groups[2].payBank, "Apple Card has no lender link")
        XCTAssertEqual(groups[3].payBank?.buttonTitle, "Pay Citi")
    }

    func testCardsWithTheSameBankIDShareAGroupEvenIfTheNameIsSpelledDifferently() {
        let cards = dashboardCards([
            card("One", issuer: "Chase", issuerID: "chase", balance: "10", minimum: "5", due: (11, 28)),
            card("Two", issuer: "JPMorgan Chase", issuerID: "chase", balance: "10", minimum: "5", due: (11, 29)),
        ])
        XCTAssertEqual(BankGroup.groups(from: cards).count, 1)
    }

    func testCardsTypedInByHandGroupByTheirName() {
        let cards = dashboardCards([
            card("One", issuer: "Navy", balance: "10", minimum: "5", due: (11, 28)),
            card("Two", issuer: "navy", balance: "10", minimum: "5", due: (11, 29)),
            card("Three", issuer: "Local", balance: "10", minimum: "5", due: (11, 30)),
        ])
        XCTAssertEqual(BankGroup.groups(from: cards).map(\.cards.count), [2, 1])
    }

    func testNoCardsMeansNoGroups() {
        XCTAssertTrue(BankGroup.groups(from: []).isEmpty)
    }

    // MARK: By week

    func testWeeksMatchTheDesign() {
        let sections = WeekSection.sections(from: dashboardCards(), today: today, calendar: calendar)
        XCTAssertEqual(sections.map(\.title), ["This week", "Next week", "Dec 6 – Dec 12", "Dec 13 – Dec 19"])
        XCTAssertEqual(sections.map(\.dates), ["Nov 22 – Nov 28", "Nov 29 – Dec 5", nil, nil])
        XCTAssertEqual(sections.map(\.cards.count), [1, 1, 2, 1])
    }

    func testEachWeekAddsUpItsMinimums() {
        let sections = WeekSection.sections(from: dashboardCards(), today: today, calendar: calendar)
        XCTAssertEqual(sections.map(\.totalMinimums), [amount("75"), amount("35"), amount("60"), amount("60")])
        XCTAssertEqual(sections.map(\.totalMinimums).reduce(0, +), amount("230"))
    }

    func testWeeksRunSundayToSaturday() {
        let sections = WeekSection.sections(from: dashboardCards(), today: today, calendar: calendar)
        XCTAssertEqual(sections[0].start, day(2026, 11, 22))
        XCTAssertEqual(sections[0].end, day(2026, 11, 28))
        // A card due on the Saturday is still in "This week". One due the next day is not.
        XCTAssertEqual(sections[0].cards.map(\.card.catalogCard.name), ["Chase Sapphire Preferred"])
    }

    func testAWeekWithNoCardIsLeftOut() {
        let sections = WeekSection.sections(from: dashboardCards(), today: today, calendar: calendar)
        // Nothing is due Dec 13 - Dec 19 other than Citi, and nothing after, so no empty weeks appear.
        XCTAssertFalse(sections.contains { $0.cards.isEmpty })
    }

    func testCardsInAWeekGoByDay() {
        let sections = WeekSection.sections(from: dashboardCards(), today: today, calendar: calendar)
        XCTAssertEqual(sections[2].cards.map(\.card.catalogCard.name), ["Chase Freedom Unlimited", "Apple Card"])
    }

    func testAPaidCardMovesToTheWeekOfItsNextDueDay() {
        let cards = tracked
        let paid = [cards[0].id: day(2026, 11, 28)]
        let sections = WeekSection.sections(from: dashboardCards(cards, paid: paid), today: today, calendar: calendar)
        // Dec 28, 2026 is a Monday: the week of Dec 27 to Jan 2.
        XCTAssertEqual(sections.last?.title, "Dec 27 – Jan 2")
        XCTAssertEqual(sections.last?.cards.map(\.card.catalogCard.name), ["Chase Sapphire Preferred"])
        XCTAssertNil(sections.first(where: { $0.title == "This week" }))
    }

    func testTheWeekAfterThisOneIsCalledNextWeekAcrossTheNewYear() {
        // Today is Dec 29, 2026 (Tuesday). Jan 3, 2027 is the Sunday that starts the next week.
        let cards = DashboardData(
            cards: [card("Early", issuer: "Bank", balance: "10", minimum: "5", due: (1, 3))],
            sortedBy: .dueDate,
            today: day(2026, 12, 29),
            calendar: calendar
        ).cards
        let sections = WeekSection.sections(from: cards, today: day(2026, 12, 29), calendar: calendar)
        XCTAssertEqual(sections.map(\.title), ["Next week"])
        XCTAssertEqual(sections.first?.dates, "Jan 3 – Jan 9")
    }

    func testNoCardsMeansNoWeeks() {
        XCTAssertTrue(WeekSection.sections(from: [], today: today, calendar: calendar).isEmpty)
    }
}
