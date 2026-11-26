import XCTest
@testable import CreditCardTracker

/// "Mark paid" as the store keeps it: one paid due day per card.
@MainActor
final class MarkPaidStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func storeWithTwoCards() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-freedom-unlimited")))
        store.toggleSelection(of: try XCTUnwrap(CardCatalog.card(withID: "us-chase-sapphire-preferred")))
        store.continueFromPickCards()
        return store
    }

    private func date(_ month: Int, _ day: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    func testMarkPaidRemembersTheStartOfTheDueDay() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        store.markPaid(id, dueDate: date(11, 28, hour: 15), calendar: calendar)
        XCTAssertEqual(store.paidDueDates[id], date(11, 28))
    }

    func testUndoPaidTakesItBack() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        store.markPaid(id, dueDate: date(11, 28), calendar: calendar)
        store.undoPaid(id)
        XCTAssertNil(store.paidDueDates[id])
    }

    func testMarkingOneCardLeavesTheOtherAlone() throws {
        let store = try storeWithTwoCards()
        store.markPaid(store.cards[0].id, dueDate: date(11, 28), calendar: calendar)
        XCTAssertNil(store.paidDueDates[store.cards[1].id])
    }

    func testUnknownCardsCannotBeMarkedPaid() throws {
        let store = try storeWithTwoCards()
        store.markPaid(UUID(), dueDate: date(11, 28), calendar: calendar)
        XCTAssertTrue(store.paidDueDates.isEmpty)
    }

    func testRemovingACardForgetsItsPaidDay() throws {
        let store = try storeWithTwoCards()
        let id = store.cards[0].id
        store.markPaid(id, dueDate: date(11, 28), calendar: calendar)
        store.removeCard(id)
        XCTAssertNil(store.paidDueDates[id])
    }
}
