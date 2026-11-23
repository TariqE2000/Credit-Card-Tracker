import XCTest
@testable import CreditCardTracker

final class NotListedCardModelTests: XCTestCase {
    func testNotListedCardsAreMarkedCustom() {
        XCTAssertTrue(CatalogCard.custom().isCustom)
        XCTAssertFalse(CardCatalog.all[0].isCustom)
        XCTAssertEqual(CatalogCard.custom().issuer, "Not listed")
    }

    func testEachNotListedCardGetsItsOwnID() {
        XCTAssertNotEqual(CatalogCard.custom().id, CatalogCard.custom().id)
    }

    func testUnnamedCardIsCalledOtherCard() {
        XCTAssertEqual(CatalogCard.custom().displayName, "Other card")
        XCTAssertEqual(CatalogCard.custom(name: "   ").displayName, "Other card")
    }

    func testLabelIsTheFirstWordOfTheName() {
        XCTAssertEqual(CatalogCard.custom(name: "Navy Federal").issuer, "Navy")
        XCTAssertEqual(CatalogCard.custom(name: "  Costco  ").issuer, "Costco")
        XCTAssertEqual(CatalogCard.custom(name: "").issuer, "Not listed")
        XCTAssertEqual(CatalogCard.custom(name: "   ").issuer, "Not listed")
    }

    func testNamedCardShowsItsTrimmedName() {
        XCTAssertEqual(CatalogCard.custom(name: "  Navy Federal ").displayName, "Navy Federal")
    }

    func testCatalogCardsKeepTheirNames() {
        XCTAssertEqual(CardCatalog.all[0].displayName, CardCatalog.all[0].name)
    }
}

@MainActor
final class NotListedCardStoreTests: XCTestCase {
    private func card(_ id: String) throws -> CatalogCard {
        try XCTUnwrap(CardCatalog.card(withID: id))
    }

    func testTappingNotListedIncreasesTheCount() throws {
        let store = OnboardingStore()
        store.toggleSelection(of: try card("chase-freedom-unlimited"))
        store.toggleSelection(of: try card("chase-sapphire-preferred"))
        XCTAssertEqual(store.selectedCount, 2)

        store.addNotListedCard()
        XCTAssertEqual(store.selectedCount, 3)

        store.addNotListedCard()
        XCTAssertEqual(store.selectedCount, 4)
    }

    func testContinueShowsTheNotListedCardsInTheOrderTheyWerePicked() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("chase-freedom-unlimited"))
        store.addNotListedCard()
        store.toggleSelection(of: try card("apple-card"))

        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 3)
        XCTAssertFalse(store.cards[0].catalogCard.isCustom)
        XCTAssertTrue(store.cards[1].catalogCard.isCustom)
        XCTAssertEqual(store.cards[1].catalogCard.displayName, "Other card")
        XCTAssertFalse(store.cards[2].catalogCard.isCustom)
    }

    func testTwoNotListedCardsAreSeparateCards() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.addNotListedCard()
        store.addNotListedCard()

        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertNotEqual(store.cards[0].catalogCard.id, store.cards[1].catalogCard.id)
    }

    func testTypingANameSetsTheCardName() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.addNotListedCard()
        store.continueFromPickCards()
        let id = store.cards[0].id

        store.setCustomName("Navy Federal", for: id)

        XCTAssertEqual(store.card(withID: id)?.catalogCard.displayName, "Navy Federal")
    }

    func testLabelUnderTheNameFollowsTheFirstWordAsItIsTyped() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.addNotListedCard()
        store.continueFromPickCards()
        let id = store.cards[0].id
        XCTAssertEqual(store.card(withID: id)?.catalogCard.issuer, "Not listed")

        store.setCustomName("Navy Federal", for: id)
        XCTAssertEqual(store.card(withID: id)?.catalogCard.issuer, "Navy")

        store.setCustomName("Costco Anywhere Visa", for: id)
        XCTAssertEqual(store.card(withID: id)?.catalogCard.issuer, "Costco")

        store.setCustomName("", for: id)
        XCTAssertEqual(store.card(withID: id)?.catalogCard.issuer, "Not listed")
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

        // Back on "Pick your cards", the user taps another card and continues.
        store.toggleSelection(of: try card("apple-card"))
        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.cards[0].id, id)
        XCTAssertEqual(store.cards[0].catalogCard.displayName, "Credit Union")
        XCTAssertEqual(store.cards[0].details, details)
    }

    func testCatalogCardNamesCannotBeChanged() throws {
        let store = OnboardingStore()
        store.toggleSelection(of: try card("apple-card"))
        store.signIn(with: .apple)
        store.continueFromPickCards()
        let id = store.cards[0].id

        store.setCustomName("Something else", for: id)

        XCTAssertEqual(store.cards[0].catalogCard.name, "Apple Card")
    }

    func testRemovingANotListedCardLowersTheCount() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("apple-card"))
        store.addNotListedCard()
        store.continueFromPickCards()
        XCTAssertEqual(store.selectedCount, 2)

        store.removeCard(store.cards[1].id)

        XCTAssertEqual(store.selectedCount, 1)
        XCTAssertEqual(store.cards.count, 1)
    }
}
