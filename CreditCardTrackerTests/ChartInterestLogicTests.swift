import XCTest
@testable import CreditCardTracker

/// The Chart and Interest views. "Today" is Thursday Nov 26, 2026.
final class ChartInterestLogicTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US")
        return calendar
    }()

    private var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 26))!
    }

    private func amount(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US"))!
    }

    private func card(_ name: String, balance: String, apr: String?) -> TrackedCard {
        TrackedCard(
            catalogCard: CatalogCard(
                id: "test-\(name)", name: name, issuer: "Test", badgeCode: "XX", badgeColorHex: 0, issuerID: nil
            ),
            details: CardDetails(
                balance: amount(balance),
                minimumPayment: amount("25"),
                dueDate: DueDate(month: 12, day: 10),
                apr: apr.map(amount)
            )
        )
    }

    /// The five cards from the design.
    private var designCards: [TrackedCard] {
        [
            card("Chase Sapphire Preferred", balance: "2480.15", apr: "24.99"),
            card("Capital One Quicksilver", balance: "1120.40", apr: "29.74"),
            card("Chase Freedom Unlimited", balance: "860.00", apr: "23.99"),
            card("Apple Card", balance: "640.00", apr: "21.49"),
            card("Citi Double Cash", balance: "1890.22", apr: nil),
        ]
    }

    private func dashboardCards(_ cards: [TrackedCard]) -> [DashboardCard] {
        DashboardData(cards: cards, sortedBy: .dueDate, today: today, calendar: calendar).cards
    }

    private func name(_ item: DashboardCard) -> String {
        item.card.catalogCard.displayName
    }

    // MARK: Rounding

    func testRoundingToCents() {
        XCTAssertEqual(amount("27.7677").rounded(toPlaces: 2), amount("27.77"))
        XCTAssertEqual(amount("27.764").rounded(toPlaces: 2), amount("27.76"))
        XCTAssertEqual(amount("9.15").rounded(toPlaces: 1), amount("9.2"))
        XCTAssertEqual(amount("0.005").rounded(toPlaces: 2), amount("0.01"))
    }

    // MARK: Chart

    func testBarsAreBiggestBalanceFirst() {
        let bars = BalanceBar.bars(from: dashboardCards(designCards))
        XCTAssertEqual(
            bars.map { name($0.card) },
            ["Chase Sapphire Preferred", "Citi Double Cash", "Capital One Quicksilver", "Chase Freedom Unlimited", "Apple Card"]
        )
    }

    func testSharesAreToOneDecimalAndAddUpToOneHundred() {
        let bars = BalanceBar.bars(from: dashboardCards(designCards))
        XCTAssertEqual(bars.map(\.share), [amount("35.5"), amount("27.0"), amount("16.0"), amount("12.3"), amount("9.2")])
        XCTAssertEqual(bars.map(\.share).reduce(0, +), 100)
        XCTAssertEqual(bars.map(\.shareText), ["35.5%", "27.0%", "16.0%", "12.3%", "9.2%"])
    }

    func testBarLengthsRunFromTheBiggestBalanceDown() {
        let bars = BalanceBar.bars(from: dashboardCards(designCards))
        XCTAssertEqual(bars[0].fraction, 1, accuracy: 0.0001)
        XCTAssertEqual(bars[1].fraction, 1890.22 / 2480.15, accuracy: 0.0001)
        XCTAssertEqual(bars[4].fraction, 640 / 2480.15, accuracy: 0.0001)
        XCTAssertTrue(bars.allSatisfy { $0.fraction > 0 && $0.fraction <= 1 })
    }

    func testEqualBalancesGoByName() {
        let cards = [card("Zeta", balance: "100", apr: nil), card("Alpha", balance: "100", apr: nil)]
        let bars = BalanceBar.bars(from: dashboardCards(cards))
        XCTAssertEqual(bars.map { name($0.card) }, ["Alpha", "Zeta"])
    }

    func testZeroBalancesDoNotDivideByZero() {
        let bars = BalanceBar.bars(from: dashboardCards([card("Paid off", balance: "0", apr: nil)]))
        XCTAssertEqual(bars.count, 1)
        XCTAssertEqual(bars[0].share, 0)
        XCTAssertEqual(bars[0].fraction, 0)
    }

    func testNoCardsGiveNoBars() {
        XCTAssertTrue(BalanceBar.bars(from: []).isEmpty)
    }

    // MARK: Interest

    func testInterestIsHighestRateFirstAndCardsWithoutARateLast() {
        let summary = InterestSummary(cards: dashboardCards(designCards))
        XCTAssertEqual(
            summary.rows.map { name($0.card) },
            ["Capital One Quicksilver", "Chase Sapphire Preferred", "Chase Freedom Unlimited", "Apple Card", "Citi Double Cash"]
        )
        XCTAssertNil(summary.rows.last?.apr)
    }

    func testMonthlyInterestIsBalanceTimesRateOverTwelveToTheCent() {
        let summary = InterestSummary(cards: dashboardCards(designCards))
        XCTAssertEqual(
            summary.rows.map(\.monthlyInterest),
            [amount("27.77"), amount("51.65"), amount("17.19"), amount("11.46"), nil]
        )
        XCTAssertEqual(summary.rows.map(\.aprText), ["29.74%", "24.99%", "23.99%", "21.49%", nil])
    }

    func testTotalAddsUpOnlyCardsWithARate() {
        let summary = InterestSummary(cards: dashboardCards(designCards))
        XCTAssertEqual(summary.monthlyTotal, amount("108.07"))
        XCTAssertEqual(summary.countedCards, 4)
        XCTAssertEqual(summary.totalCards, 5)
        XCTAssertEqual(summary.note, "Adds up 4 of 5 cards. Citi Double Cash has no APR yet.")
    }

    func testNoteWhenEveryCardHasARate() {
        let cards = Array(designCards.prefix(4))
        let summary = InterestSummary(cards: dashboardCards(cards))
        XCTAssertEqual(summary.note, "Adds up all 4 cards.")
        XCTAssertTrue(summary.cardsWithoutAPR.isEmpty)
    }

    func testNoteWhenSeveralCardsHaveNoRate() {
        let cards = [card("A", balance: "100", apr: "20"), card("B", balance: "50", apr: nil), card("C", balance: "70", apr: nil)]
        let summary = InterestSummary(cards: dashboardCards(cards))
        XCTAssertEqual(summary.note, "Adds up 1 of 3 cards. 2 cards have no APR yet.")
    }

    func testNoRatesMeansNoEstimate() {
        let summary = InterestSummary(cards: dashboardCards([card("A", balance: "100", apr: nil)]))
        XCTAssertEqual(summary.countedCards, 0)
        XCTAssertEqual(summary.monthlyTotal, 0)
    }

    func testCardsWithoutARateGoByBalanceThenName() {
        let cards = [
            card("Small", balance: "10", apr: nil),
            card("Big", balance: "500", apr: nil),
            card("Also big", balance: "500", apr: nil),
        ]
        let summary = InterestSummary(cards: dashboardCards(cards))
        XCTAssertEqual(summary.rows.map { name($0.card) }, ["Also big", "Big", "Small"])
    }

    func testEqualRatesGoByBalance() {
        let cards = [card("Low", balance: "100", apr: "20"), card("High", balance: "900", apr: "20")]
        let summary = InterestSummary(cards: dashboardCards(cards))
        XCTAssertEqual(summary.rows.map { name($0.card) }, ["High", "Low"])
    }

    func testCardsMissingDetailsAreLeftOut() {
        let unfinished = TrackedCard(
            catalogCard: CatalogCard(id: "x", name: "Unfinished", issuer: "Test", badgeCode: "XX", badgeColorHex: 0, issuerID: nil),
            details: CardDetails()
        )
        let data = DashboardData(cards: designCards + [unfinished], sortedBy: .dueDate, today: today, calendar: calendar)
        XCTAssertEqual(InterestSummary(cards: data.cards).totalCards, 5)
        XCTAssertEqual(BalanceBar.bars(from: data.cards).count, 5)
        XCTAssertEqual(data.incomplete.count, 1)
    }
}
