import XCTest
@testable import CreditCardTracker

/// The home screen's numbers, due dates and sorting. "Today" is Thursday Nov 26, 2026 unless a test says otherwise.
final class DashboardTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
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
        balance: String?,
        minimum: String?,
        due: (month: Int, day: Int)?,
        apr: String? = nil
    ) -> TrackedCard {
        TrackedCard(
            catalogCard: CatalogCard(id: "test-\(name)", name: name, issuer: issuer, badgeCode: "XX", badgeColorHex: 0x000000),
            details: CardDetails(
                balance: balance.map { amount($0) },
                minimumPayment: minimum.map { amount($0) },
                dueDate: due.flatMap { DueDate(month: $0.month, day: $0.day) },
                apr: apr.map { amount($0) }
            )
        )
    }

    /// The same five cards as the design, plus one with no details.
    private var sample: [TrackedCard] {
        [
            card("Chase Sapphire Preferred", issuer: "Chase", balance: "2480.15", minimum: "75", due: (11, 28), apr: "24.99"),
            card("Capital One Quicksilver", issuer: "Capital One", balance: "1120.40", minimum: "35", due: (12, 3), apr: "29.74"),
            card("Chase Freedom Unlimited", issuer: "Chase", balance: "860.00", minimum: "35", due: (12, 6), apr: "23.99"),
            card("Apple Card", issuer: "Apple", balance: "640.00", minimum: "25", due: (12, 9), apr: "21.49"),
            card("Citi Double Cash", issuer: "Citi", balance: "1890.22", minimum: "60", due: (12, 14)),
            card("Discover it Cash Back", issuer: "Discover", balance: nil, minimum: nil, due: nil),
        ]
    }

    private func data(sortedBy sort: CardSort = .dueDate, today: Date? = nil, cards: [TrackedCard]? = nil) -> DashboardData {
        DashboardData(cards: cards ?? sample, sortedBy: sort, today: today ?? self.today, calendar: calendar)
    }

    private func names(_ sort: CardSort) -> [String] {
        data(sortedBy: sort).cards.map(\.card.catalogCard.name)
    }

    // MARK: Due dates

    func testDueDayLaterThisMonthStaysInThisMonth() {
        let next = DueDate(month: 11, day: 28)!.nextDue(onOrAfter: today, calendar: calendar)
        XCTAssertEqual(next, day(2026, 11, 28))
        XCTAssertEqual(DueDate(month: 11, day: 28)!.daysUntil(from: today, calendar: calendar), 2)
    }

    func testDueDayThatPassedMovesToNextMonth() {
        // Typed as Nov 14 but it is already the 26th: the next 14th is in December.
        XCTAssertEqual(DueDate(month: 11, day: 14)!.nextDue(onOrAfter: today, calendar: calendar), day(2026, 12, 14))
    }

    func testTheMonthTypedDoesNotMatter() {
        // Typed as Feb 5, but a due date repeats every month, so the next 5th is Dec 5.
        XCTAssertEqual(DueDate(month: 2, day: 5)!.nextDue(onOrAfter: today, calendar: calendar), day(2026, 12, 5))
    }

    func testDueTodayIsZeroDays() {
        XCTAssertEqual(DueDate(month: 11, day: 26)!.daysUntil(from: today, calendar: calendar), 0)
    }

    func testNextDueCrossesTheNewYear() {
        let late = day(2026, 12, 20)
        XCTAssertEqual(DueDate(month: 12, day: 5)!.nextDue(onOrAfter: late, calendar: calendar), day(2027, 1, 5))
    }

    func testShortMonthsUseTheirLastDay() {
        // The 31st does not exist in April or in February.
        XCTAssertEqual(DueDate(month: 1, day: 31)!.nextDue(onOrAfter: day(2027, 4, 10), calendar: calendar), day(2027, 4, 30))
        XCTAssertEqual(DueDate(month: 3, day: 30)!.nextDue(onOrAfter: day(2027, 2, 10), calendar: calendar), day(2027, 2, 28))
    }

    func testWhenText() {
        func text(_ days: Int) -> String {
            let date = calendar.date(byAdding: .day, value: days, to: today)!
            let parts = calendar.dateComponents([.month, .day], from: date)
            let tracked = card("A", issuer: "A", balance: "1", minimum: "1", due: (parts.month!, parts.day!))
            return DashboardCard(tracked, today: today, calendar: calendar)!.whenText
        }
        XCTAssertEqual(text(0), "today")
        XCTAssertEqual(text(1), "tomorrow")
        XCTAssertEqual(text(2), "in 2 days")
        XCTAssertEqual(text(12), "in 12 days")
    }

    func testUrgencyColors() {
        XCTAssertEqual(DueUrgency(daysUntilDue: 0), .urgent)
        XCTAssertEqual(DueUrgency(daysUntilDue: 2), .urgent)
        XCTAssertEqual(DueUrgency(daysUntilDue: 3), .soon)
        XCTAssertEqual(DueUrgency(daysUntilDue: 7), .soon)
        XCTAssertEqual(DueUrgency(daysUntilDue: 8), .calm)
    }

    // MARK: Totals

    func testTotalsMatchTheDesign() {
        let result = data()
        XCTAssertEqual(result.totalBalance, amount("6990.77"))
        XCTAssertEqual(result.totalMinimums, amount("230"))
        // Nov 28 (2 days) and Dec 3 (7 days) are inside the week. Dec 6 is 10 days away.
        XCTAssertEqual(result.dueSoonTotal, amount("110"))
        XCTAssertEqual(result.cards.count, 5)
    }

    func testCardsWithoutDetailsAreLeftOutOfTotalsAndShownLast() {
        let result = data()
        XCTAssertEqual(result.incomplete.map(\.catalogCard.name), ["Discover it Cash Back"])
        XCTAssertFalse(result.cards.contains { $0.card.catalogCard.name == "Discover it Cash Back" })
    }

    func testNextDueIsTheSoonestCard() {
        XCTAssertEqual(data().nextDue?.card.catalogCard.name, "Chase Sapphire Preferred")
        XCTAssertEqual(data().nextDue?.dueOnText, "Nov 28")
    }

    func testNoCardsGivesZerosAndNoBanner() {
        let result = data(cards: [])
        XCTAssertEqual(result.totalBalance, 0)
        XCTAssertEqual(result.totalMinimums, 0)
        XCTAssertEqual(result.dueSoonTotal, 0)
        XCTAssertNil(result.nextDue)
        XCTAssertNil(result.dueSoon)
    }

    // MARK: Banner

    func testBannerShowsTheCardDueWithinTheWeek() {
        XCTAssertEqual(data().dueSoon?.card.catalogCard.name, "Chase Sapphire Preferred")
        XCTAssertEqual(data().dueSoon?.dueChipText, "Due in 2 days")
    }

    func testNoBannerWhenNothingIsDueWithinTheWeek() {
        let farAway = [card("Citi Double Cash", issuer: "Citi", balance: "1890.22", minimum: "60", due: (12, 14))]
        XCTAssertNil(data(cards: farAway).dueSoon)
    }

    // MARK: Sorting

    func testSortByDueDate() {
        XCTAssertEqual(names(.dueDate), [
            "Chase Sapphire Preferred", "Capital One Quicksilver", "Chase Freedom Unlimited", "Apple Card", "Citi Double Cash",
        ])
    }

    func testSortByBalanceBiggestFirst() {
        XCTAssertEqual(names(.balance), [
            "Chase Sapphire Preferred", "Citi Double Cash", "Capital One Quicksilver", "Chase Freedom Unlimited", "Apple Card",
        ])
    }

    func testSortByMinimumPaymentBiggestFirstAndTiesGoByDueDate() {
        // Quicksilver and Freedom Unlimited both have a $35 minimum. Quicksilver is due first.
        XCTAssertEqual(names(.minimumPayment), [
            "Chase Sapphire Preferred", "Citi Double Cash", "Capital One Quicksilver", "Chase Freedom Unlimited", "Apple Card",
        ])
    }

    func testSortByBankAtoZ() {
        XCTAssertEqual(names(.bank), [
            "Apple Card", "Capital One Quicksilver", "Chase Sapphire Preferred", "Chase Freedom Unlimited", "Citi Double Cash",
        ])
    }

    func testSortByInterestRateHighestFirstAndNoAprLast() {
        XCTAssertEqual(names(.interestRate), [
            "Capital One Quicksilver", "Chase Sapphire Preferred", "Chase Freedom Unlimited", "Apple Card", "Citi Double Cash",
        ])
    }

    func testSortNeverChangesTheTotals() {
        for sort in CardSort.allCases {
            XCTAssertEqual(data(sortedBy: sort).totalBalance, amount("6990.77"), "\(sort)")
            XCTAssertEqual(data(sortedBy: sort).incomplete.count, 1, "\(sort)")
        }
    }

    func testEverySortHasANameAndAMenuLabel() {
        for sort in CardSort.allCases {
            XCTAssertFalse(sort.title.isEmpty)
            XCTAssertTrue(sort.menuTitle.hasPrefix(sort.title))
        }
        XCTAssertEqual(CardSort.dueDate.title, "Due date")
    }
}
