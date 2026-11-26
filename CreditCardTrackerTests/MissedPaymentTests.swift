import XCTest
@testable import CreditCardTracker

/// Due days that pass without being marked as handled show up as missed payments.
/// "Today" is Thursday Nov 26, 2026, unless a test says otherwise.
@MainActor
final class MissedPaymentTests: XCTestCase {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private var today: Date { day(2026, 11, 26) }

    /// A store with one card due on `dueDay` of every month. The due day is entered on `enteredOn`,
    /// so due days before that day are not counted as missed.
    private func store(dueDay: Int, enteredOn: Date, minimum: Decimal = 25) throws -> (OnboardingStore, UUID) {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-freedom-unlimited")))
        store.continueFromPickCards()
        let id = store.cards[0].id
        store.saveDetails(
            CardDetails(balance: 100, minimumPayment: minimum, dueDate: DueDate(month: 11, day: dueDay), apr: nil),
            for: id,
            today: enteredOn,
            calendar: calendar
        )
        return (store, id)
    }

    private func data(_ store: OnboardingStore, on date: Date? = nil, sortedBy sort: CardSort = .dueDate) -> DashboardData {
        DashboardData(
            cards: store.cards,
            sortedBy: sort,
            paid: store.paidDueDates,
            settled: store.settledDueDates,
            today: date ?? today,
            calendar: calendar
        )
    }

    private func item(_ id: UUID, in store: OnboardingStore, on date: Date? = nil) throws -> DashboardCard {
        try XCTUnwrap(data(store, on: date).cards.first { $0.id == id })
    }

    // MARK: When a payment counts as missed

    func testACardAddedAfterItsDueDayStartsWithNothingMissed() throws {
        // Due on the 20th, entered on Nov 26: Nov 20 had already passed, and the app cannot know about it.
        let (store, id) = try store(dueDay: 20, enteredOn: today)
        let card = try item(id, in: store)
        XCTAssertFalse(card.isMissed)
        XCTAssertNil(card.missedLineText)
        XCTAssertEqual(card.dueOnText, "Dec 20")
    }

    func testADueDayThatPassedWithoutBeingMarkedIsMissed() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        let card = try item(id, in: store)
        XCTAssertTrue(card.isMissed)
        XCTAssertEqual(card.missedDueDates, [day(2026, 11, 20)])
        XCTAssertEqual(card.missedLineText, "Missed Nov 20 · 6 days ago")
        XCTAssertEqual(card.dueOnText, "Dec 20")
        XCTAssertFalse(card.isPaid)
    }

    func testAPaymentDueTodayIsNotMissedUntilTomorrow() throws {
        let (store, id) = try store(dueDay: 26, enteredOn: day(2026, 10, 30))
        XCTAssertFalse(try item(id, in: store).isMissed)
        XCTAssertEqual(try item(id, in: store).dueOnText, "Nov 26")

        let tomorrow = try item(id, in: store, on: day(2026, 11, 27))
        XCTAssertEqual(tomorrow.missedDueDates, [day(2026, 11, 26)])
    }

    func testAPaymentMissedYesterdayReadsYesterday() throws {
        let (store, id) = try store(dueDay: 25, enteredOn: day(2026, 10, 30))
        XCTAssertEqual(try item(id, in: store).missedLineText, "Missed Nov 25 · yesterday")
    }

    func testACardWithNoSettledDayIsNeverFlagged() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        let plain = DashboardData(cards: store.cards, sortedBy: .dueDate, today: today, calendar: calendar)
        XCTAssertFalse(try XCTUnwrap(plain.cards.first { $0.id == id }).isMissed)
        XCTAssertEqual(plain.missedCount, 0)
    }

    // MARK: Several months

    func testSeveralMissedMonthsStayOneCardAndOneRow() throws {
        let (store, id) = try store(dueDay: 10, enteredOn: day(2026, 9, 15))
        let result = data(store)
        XCTAssertEqual(result.cards.count, 1)

        let card = try XCTUnwrap(result.cards.first { $0.id == id })
        XCTAssertEqual(card.missedDueDates, [day(2026, 10, 10), day(2026, 11, 10)])
        XCTAssertEqual(card.missedHeadline, "2 payments missed")
        XCTAssertEqual(card.missedTail, "since Oct 10")
        XCTAssertEqual(card.missedLineText, "2 payments missed")
        XCTAssertEqual(card.dueOnText, "Dec 10")
    }

    func testTheMinimumIsCountedOncePerCardHoweverManyMonthsWereMissed() throws {
        let (store, _) = try store(dueDay: 10, enteredOn: day(2026, 9, 15), minimum: 25)
        let result = data(store)
        XCTAssertEqual(result.missedTotal, 25)
        XCTAssertEqual(result.missedCount, 1)
    }

    func testTheNoticeNamesTheDays() throws {
        let (store, id) = try store(dueDay: 10, enteredOn: day(2026, 9, 15))
        let card = try item(id, in: store)
        let notice = try XCTUnwrap(card.missedNotice)
        XCTAssertTrue(notice.contains("2 payments: Oct 10 and Nov 10"))
        XCTAssertTrue(notice.contains("Check your statement"))
        XCTAssertEqual(card.missedCaption, "Marks both missed payments as paid. Next due: Dec 10.")
    }

    func testTheNoticeForOnePaymentAndItsCaption() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        let card = try item(id, in: store)
        XCTAssertEqual(
            card.missedNotice,
            "You may have missed the Nov 20 payment. If you already paid it, tap Mark paid and this goes away."
        )
        XCTAssertEqual(card.missedCaption, "Marks the Nov 20 payment as paid. Next due: Dec 20.")
    }

    func testALongRunOfMissedMonthsIsSummedUpAsARange() throws {
        let (store, id) = try store(dueDay: 10, enteredOn: day(2026, 6, 15))
        let card = try item(id, in: store)
        XCTAssertEqual(card.missedDueDates.count, 5)
        XCTAssertTrue(try XCTUnwrap(card.missedNotice).contains("Jul 10 through Nov 10"))
        XCTAssertEqual(card.missedCaption, "Marks all 5 missed payments as paid. Next due: Dec 10.")
    }

    // MARK: Mark paid

    func testMarkPaidClearsEveryMissedPaymentAndLeavesTheComingOne() throws {
        let (store, id) = try store(dueDay: 10, enteredOn: day(2026, 9, 15))

        let nowPaid = store.togglePaid(try item(id, in: store), calendar: calendar)

        XCTAssertFalse(nowPaid, "the coming payment is not marked paid")
        XCTAssertNil(store.paidDueDates[id])
        let after = try item(id, in: store)
        XCTAssertFalse(after.isMissed)
        XCTAssertFalse(after.isPaid)
        XCTAssertEqual(after.dueOnText, "Dec 10")
    }

    func testAfterClearingMissedPaymentsTheButtonMarksTheComingOne() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        store.togglePaid(try item(id, in: store), calendar: calendar)

        let nowPaid = store.togglePaid(try item(id, in: store), calendar: calendar)

        XCTAssertTrue(nowPaid)
        XCTAssertEqual(store.paidDueDates[id], day(2026, 12, 20))
    }

    func testClearMissedDoesNothingWhenNothingIsMissed() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: today)
        let before = store.settledDueDates
        store.clearMissed(try item(id, in: store), calendar: calendar)
        XCTAssertEqual(store.settledDueDates, before)
    }

    func testPayingBeforeTheDueDayDoesNotLeaveAMissedPaymentBehind() throws {
        let (store, id) = try store(dueDay: 28, enteredOn: today)
        store.togglePaid(try item(id, in: store), calendar: calendar)

        XCTAssertFalse(try item(id, in: store, on: day(2026, 11, 29)).isMissed)
        // The Dec 28 payment was not marked, so it is missed once Dec 28 has passed.
        XCTAssertEqual(try item(id, in: store, on: day(2026, 12, 29)).missedDueDates, [day(2026, 12, 28)])
    }

    func testTakingBackALaterMonthDoesNotBringAnOldMonthBack() throws {
        let (store, id) = try store(dueDay: 28, enteredOn: today)
        store.togglePaid(try item(id, in: store), calendar: calendar)       // marks Nov 28
        let later = try item(id, in: store, on: day(2026, 11, 29))
        store.togglePaid(later, calendar: calendar)                         // marks Dec 28, replacing Nov 28
        XCTAssertEqual(store.paidDueDates[id], day(2026, 12, 28))

        store.undoPaid(id)

        XCTAssertFalse(try item(id, in: store, on: day(2026, 11, 29)).isMissed)
    }

    // MARK: Editing and removing

    func testEditingOtherDetailsKeepsTheMissedPayments() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        store.saveDetails(
            CardDetails(balance: 250, minimumPayment: 30, dueDate: DueDate(month: 11, day: 20), apr: nil),
            for: id,
            today: today,
            calendar: calendar
        )
        XCTAssertTrue(try item(id, in: store).isMissed)
    }

    func testChangingTheDueDayStartsFresh() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        XCTAssertTrue(try item(id, in: store).isMissed)

        store.saveDetails(
            CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 11, day: 10), apr: nil),
            for: id,
            today: today,
            calendar: calendar
        )
        XCTAssertFalse(try item(id, in: store).isMissed)
    }

    func testRemovingACardForgetsItsSettledDay() throws {
        let (store, id) = try store(dueDay: 20, enteredOn: day(2026, 11, 10))
        XCTAssertNotNil(store.settledDueDates[id])
        store.removeCard(id)
        XCTAssertNil(store.settledDueDates[id])
    }

    // MARK: The list and the totals

    func testMissedCardsComeFirstWhenSortedByDueDate() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-freedom-unlimited")))
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-sapphire-preferred")))
        store.continueFromPickCards()
        let missedID = store.cards[0].id
        let soonID = store.cards[1].id
        // Freedom: due the 20th, entered Nov 10, so Nov 20 is missed. Sapphire: due the 28th, two days away.
        store.saveDetails(
            CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 11, day: 20), apr: nil),
            for: missedID, today: day(2026, 11, 10), calendar: calendar
        )
        store.saveDetails(
            CardDetails(balance: 200, minimumPayment: 35, dueDate: DueDate(month: 11, day: 28), apr: nil),
            for: soonID, today: day(2026, 11, 10), calendar: calendar
        )

        let result = data(store)
        XCTAssertEqual(result.cards.map(\.id), [missedID, soonID])
        XCTAssertEqual(result.missedTotal, 25)
        // The card due soonest is still the one with the nearest next due day, and it fills the banner.
        XCTAssertEqual(result.nextDue?.id, soonID)
        XCTAssertEqual(result.dueSoon?.id, soonID)
    }

    // MARK: Due day helpers

    func testPreviousDueSkipsToday() throws {
        let due = try XCTUnwrap(DueDate(month: 1, day: 26))
        XCTAssertEqual(due.previousDue(before: today, calendar: calendar), day(2026, 10, 26))
        XCTAssertEqual(due.previousDue(before: day(2026, 11, 27), calendar: calendar), day(2026, 11, 26))
    }

    func testShortMonthsUseTheLastDay() throws {
        let due = try XCTUnwrap(DueDate(month: 1, day: 31))
        XCTAssertEqual(due.previousDue(before: day(2026, 12, 1), calendar: calendar), day(2026, 11, 30))
        XCTAssertEqual(
            due.missedDays(after: day(2026, 8, 31), before: day(2026, 12, 1), calendar: calendar),
            [day(2026, 9, 30), day(2026, 10, 31), day(2026, 11, 30)]
        )
    }

    func testNothingIsMissedWhenTheSettledDayIsToday() throws {
        let due = try XCTUnwrap(DueDate(month: 11, day: 26))
        XCTAssertEqual(due.missedDays(after: today, before: today, calendar: calendar), [])
    }
}
