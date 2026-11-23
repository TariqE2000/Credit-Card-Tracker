import XCTest
@testable import CreditCardTracker

final class NotListedBankModelTests: XCTestCase {
    func testNotListedBanksAreMarkedCustom() {
        XCTAssertTrue(Issuer.custom().isCustom)
        XCTAssertFalse(BuiltInIssuers.all[0].isCustom)
    }

    func testEachNotListedBankGetsItsOwnID() {
        XCTAssertNotEqual(Issuer.custom().id, Issuer.custom().id)
    }

    func testUnnamedBankIsCalledOtherBank() {
        XCTAssertEqual(Issuer.custom().displayName, "Other bank")
        XCTAssertEqual(Issuer.custom(name: "   ").displayName, "Other bank")
    }

    func testNamedBankShowsItsTrimmedName() {
        XCTAssertEqual(Issuer.custom(name: "  Navy Federal ").displayName, "Navy Federal")
    }

    func testListedIssuersKeepTheirNames() {
        XCTAssertEqual(BuiltInIssuers.all[0].displayName, BuiltInIssuers.all[0].name)
    }
}

@MainActor
final class NotListedBankStoreTests: XCTestCase {
    private func issuer(_ id: String) throws -> Issuer {
        try XCTUnwrap(BuiltInIssuers.issuer(withID: id))
    }

    func testTappingNotListedIncreasesTheCount() throws {
        let store = OnboardingStore()
        store.toggleSelection(of: try issuer("chase"))
        store.toggleSelection(of: try issuer("amex"))
        XCTAssertEqual(store.selectedCount, 2)

        store.addNotListedCard()
        XCTAssertEqual(store.selectedCount, 3)

        store.addNotListedCard()
        XCTAssertEqual(store.selectedCount, 4)
    }

    func testContinueShowsTheNotListedBanksInTheOrderTheyWerePicked() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try issuer("chase"))
        store.addNotListedCard()
        store.toggleSelection(of: try issuer("amex"))

        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 3)
        XCTAssertFalse(store.cards[0].issuer.isCustom)
        XCTAssertTrue(store.cards[1].issuer.isCustom)
        XCTAssertEqual(store.cards[1].issuer.displayName, "Other bank")
        XCTAssertFalse(store.cards[2].issuer.isCustom)
    }

    func testTwoNotListedBanksAreSeparateCards() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.addNotListedCard()
        store.addNotListedCard()

        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertNotEqual(store.cards[0].issuer.id, store.cards[1].issuer.id)
        XCTAssertEqual(store.title(of: store.cards[0]), "Other bank", "not-listed banks are never numbered")
    }

    func testTypingANameSetsTheBankName() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.addNotListedCard()
        store.continueFromPickCards()
        let id = store.cards[0].id

        store.setCustomName("Navy Federal", for: id)

        XCTAssertEqual(store.card(withID: id)?.issuer.displayName, "Navy Federal")
        XCTAssertEqual(store.title(of: store.cards[0]), "Navy Federal")
    }

    func testNameAndDetailsSurviveGoingBackAndContinuingAgain() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.addNotListedCard()
        store.continueFromPickCards()
        let id = store.cards[0].id
        let details = CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 3, day: 9))
        store.setCustomName("Credit Union", for: id)
        store.saveDetails(details, for: id)

        // Back on "Pick your cards", the user taps another issuer and continues.
        store.toggleSelection(of: try issuer("amex"))
        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.cards[0].id, id)
        XCTAssertEqual(store.cards[0].issuer.displayName, "Credit Union")
        XCTAssertEqual(store.cards[0].details, details)
    }

    func testListedIssuerNamesCannotBeChanged() throws {
        let store = OnboardingStore()
        store.toggleSelection(of: try issuer("amex"))
        store.signIn(with: .apple)
        store.continueFromPickCards()
        let id = store.cards[0].id

        store.setCustomName("Something else", for: id)

        XCTAssertEqual(store.cards[0].issuer.name, "American Express")
    }

    func testRemovingANotListedBankLowersTheCount() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try issuer("amex"))
        store.addNotListedCard()
        store.continueFromPickCards()
        XCTAssertEqual(store.selectedCount, 2)

        store.removeCard(store.cards[1].id)

        XCTAssertEqual(store.selectedCount, 1)
        XCTAssertEqual(store.cards.count, 1)
    }
}
