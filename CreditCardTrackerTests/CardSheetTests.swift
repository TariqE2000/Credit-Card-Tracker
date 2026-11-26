import XCTest
@testable import CreditCardTracker

/// The card sheet's "Mark paid" / "Mark unpaid" button and the dates in its captions.
/// "Today" is Thursday Nov 26, 2026.
@MainActor
final class CardSheetTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var today: Date { day(2026, 11, 26) }

    /// Two cards with details: the first due Nov 28 (2 days away), the second due Dec 14 (18 days away).
    private func storeWithTwoCards() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-freedom-unlimited")))
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-sapphire-preferred")))
        store.continueFromPickCards()
        store.saveDetails(
            CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 11, day: 28), apr: nil),
            for: store.cards[0].id
        )
        store.saveDetails(
            CardDetails(balance: 200, minimumPayment: 35, dueDate: DueDate(month: 12, day: 14), apr: nil),
            for: store.cards[1].id
        )
        return store
    }

    private func item(_ id: UUID, in store: OnboardingStore, today: Date? = nil) throws -> DashboardCard {
        let data = DashboardData(
            cards: store.cards,
            sortedBy: .dueDate,
            paid: store.paidDueDates,
            today: today ?? self.today,
            calendar: calendar
        )
        return try XCTUnwrap(data.cards.first { $0.id == id })
    }

    // MARK: The button

    func testButtonMarksAnUnpaidCardAsPaid() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id

        let nowPaid = store.togglePaid(try item(id, in: store), calendar: calendar)

        XCTAssertTrue(nowPaid)
        XCTAssertEqual(store.paidDueDates[id], day(2026, 11, 28))
        let after = try item(id, in: store)
        XCTAssertTrue(after.isPaid)
        XCTAssertEqual(after.dueOnText, "Dec 28")
        XCTAssertNil(after.payURL)
    }

    func testButtonMarksAPaidCardAsUnpaid() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        store.togglePaid(try item(id, in: store), calendar: calendar)

        let nowPaid = store.togglePaid(try item(id, in: store), calendar: calendar)

        XCTAssertFalse(nowPaid)
        XCTAssertNil(store.paidDueDates[id])
        let after = try item(id, in: store)
        XCTAssertFalse(after.isPaid)
        XCTAssertEqual(after.dueOnText, "Nov 28")
        XCTAssertEqual(after.nextDueDate, day(2026, 11, 28))
        XCTAssertEqual(after.payURL, PayLinks.url(for: after.card.catalogCard))
    }

    func testPressingTwiceLeavesTheCardAsItWas() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        let before = try item(id, in: store)

        store.togglePaid(before, calendar: calendar)
        store.togglePaid(try item(id, in: store), calendar: calendar)

        XCTAssertEqual(try item(id, in: store), before)
        XCTAssertTrue(store.paidDueDates.isEmpty)
    }

    func testButtonLeavesTheOtherCardAlone() throws {
        let store = try storeWithTwoCards()
        store.togglePaid(try item(store.cards[0].id, in: store), calendar: calendar)
        XCTAssertNil(store.paidDueDates[store.cards[1].id])
        XCTAssertFalse(try item(store.cards[1].id, in: store).isPaid)

        store.togglePaid(try item(store.cards[1].id, in: store), calendar: calendar)
        store.togglePaid(try item(store.cards[0].id, in: store), calendar: calendar)
        XCTAssertNil(store.paidDueDates[store.cards[0].id])
        XCTAssertEqual(store.paidDueDates[store.cards[1].id], day(2026, 12, 14))
    }

    func testACardFarFromDueCanBePaidEarly() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[1].id

        store.togglePaid(try item(id, in: store), calendar: calendar)

        let after = try item(id, in: store)
        XCTAssertTrue(after.isPaid)
        XCTAssertEqual(after.nextDueDate, day(2027, 1, 14))
    }

    func testPaidWearsOffAndTheButtonThenMarksTheNewDay() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        store.togglePaid(try item(id, in: store), calendar: calendar)

        // On Nov 29 the coming due day is Dec 28, which was not paid.
        let later = try item(id, in: store, today: day(2026, 11, 29))
        XCTAssertFalse(later.isPaid)

        let nowPaid = store.togglePaid(later, calendar: calendar)
        XCTAssertTrue(nowPaid)
        XCTAssertEqual(store.paidDueDates[id], day(2026, 12, 28))
    }

    // MARK: Dates in the captions

    func testAnUnpaidCardKnowsWhereMarkPaidMovesIt() throws {
        let store = try storeWithTwoCards()
        let card = try item(store.cards[0].id, in: store)
        XCTAssertEqual(card.dueOnText, "Nov 28")
        XCTAssertEqual(card.afterDueText, "Dec 28")
        XCTAssertNil(card.paidDueText)
    }

    func testAPaidCardKnowsTheDayThatWasMarked() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        store.togglePaid(try item(id, in: store), calendar: calendar)

        let card = try item(id, in: store)
        XCTAssertEqual(card.paidDueText, "Nov 28")
        XCTAssertEqual(card.dueOnText, "Dec 28")
        XCTAssertEqual(card.afterDueText, "Jan 28")
    }

    func testTheDayAfterIsClampedToTheEndOfAShortMonth() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        // Due on the 31st. Today is Jan 30, 2027, so the coming day is Jan 31 and the one after is Feb 28.
        store.saveDetails(
            CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 1, day: 31), apr: nil),
            for: id
        )
        let card = try item(id, in: store, today: day(2027, 1, 30))
        XCTAssertEqual(card.dueOnText, "Jan 31")
        XCTAssertEqual(card.afterDueText, "Feb 28")
    }
}
