import XCTest
@testable import CreditCardTracker

/// "Add another card" on the review screen: pick more cards, fill in only the new ones, land back on review.
@MainActor
final class AddAnotherCardTests: XCTestCase {
    private func card(_ id: String) throws -> CatalogCard {
        try XCTUnwrap(CardCatalog.card(withID: id))
    }

    /// Two cards picked, the first one filled in, and the review screen open.
    private func storeOnReview() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("us-chase-freedom-unlimited"))
        store.toggleSelection(of: try card("us-chase-sapphire-preferred"))
        store.continueFromPickCards()
        store.saveDetails(
            CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 12, day: 14), apr: nil),
            for: store.cards[0].id
        )
        store.advance(from: store.cards[0].id)
        store.advance(from: store.cards[1].id)
        XCTAssertEqual(store.path.last, .review)
        return store
    }

    func testAddAnotherCardOpensPickCardsWithCurrentCardsTicked() throws {
        let store = try storeOnReview()
        store.startAddingCards()

        XCTAssertEqual(store.path.last, .addCards)
        XCTAssertTrue(store.isSelected(try card("us-chase-freedom-unlimited")))
        XCTAssertTrue(store.isSelected(try card("us-chase-sapphire-preferred")))
        XCTAssertTrue(store.isLocked(try card("us-chase-freedom-unlimited")))
        XCTAssertFalse(store.isLocked(try card("us-apple-card")))
        XCTAssertEqual(store.newPickCount, 0)
    }

    func testOnlyNewCardsAreCounted() throws {
        let store = try storeOnReview()
        store.startAddingCards()

        store.toggleSelection(of: try card("us-apple-card"))
        store.addNotListedCard()

        XCTAssertEqual(store.newPickCount, 2)
        XCTAssertEqual(store.selectedCount, 4)
    }

    func testContinueKeepsCurrentCardsAndOpensTheFirstNewCard() throws {
        let store = try storeOnReview()
        let firstCard = store.cards[0]
        store.startAddingCards()
        store.toggleSelection(of: try card("us-apple-card"))
        store.addNotListedCard()

        store.continueFromAddCards()

        XCTAssertEqual(store.cards.count, 4)
        XCTAssertEqual(store.cards[0], firstCard)
        XCTAssertEqual(store.cards[2].catalogCard.id, "us-apple-card")
        XCTAssertTrue(store.cards[3].catalogCard.isCustom)
        XCTAssertEqual(store.path.last, .cardForm(store.cards[2].id))

        // "Card 1 of 2" counts the new cards only.
        XCTAssertEqual(store.progress(for: store.cards[2].id).position, 1)
        XCTAssertEqual(store.progress(for: store.cards[2].id).total, 2)
        XCTAssertEqual(store.progress(for: store.cards[3].id).position, 2)
    }

    func testFinishingTheLastNewCardReturnsToTheReviewScreen() throws {
        let store = try storeOnReview()
        store.startAddingCards()
        store.toggleSelection(of: try card("us-apple-card"))
        store.addNotListedCard()
        store.continueFromAddCards()
        let first = store.cards[2].id
        let second = store.cards[3].id

        store.advance(from: first)
        XCTAssertEqual(store.path.last, .cardForm(second))

        store.advance(from: second)
        XCTAssertEqual(store.path.last, .review)
        XCTAssertEqual(store.path.filter { $0 == .review }.count, 1)
        XCTAssertFalse(store.path.contains(.addCards))
        XCTAssertTrue(store.addBatch.isEmpty)
        XCTAssertEqual(store.cards.count, 4)
    }

    func testRemovingANewCardMovesOnToTheNextOne() throws {
        let store = try storeOnReview()
        store.startAddingCards()
        store.toggleSelection(of: try card("us-apple-card"))
        store.addNotListedCard()
        store.continueFromAddCards()
        let first = store.cards[2].id
        let second = store.cards[3].id

        store.removeCard(first)
        XCTAssertEqual(store.path.last, .cardForm(second))
        XCTAssertEqual(store.cards.count, 3)

        store.removeCard(second)
        XCTAssertEqual(store.path.last, .review)
        XCTAssertEqual(store.cards.count, 2)
        XCTAssertFalse(store.path.contains(.addCards))
    }

    func testStartingAgainForgetsPicksThatWereNotContinued() throws {
        let store = try storeOnReview()
        store.startAddingCards()
        store.toggleSelection(of: try card("us-apple-card"))
        XCTAssertEqual(store.newPickCount, 1)

        // Back to the review screen without continuing, then "Add another card" again.
        store.path.removeLast()
        store.startAddingCards()

        XCTAssertEqual(store.newPickCount, 0)
        XCTAssertFalse(store.isSelected(try card("us-apple-card")))
        XCTAssertEqual(store.cards.count, 2)
    }

    func testFirstPassFormsStillCountEveryCard() throws {
        let store = OnboardingStore()
        store.toggleSelection(of: try card("us-chase-freedom-unlimited"))
        store.toggleSelection(of: try card("us-chase-sapphire-preferred"))
        store.continueFromPickCards()

        XCTAssertEqual(store.progress(for: store.cards[0].id).position, 1)
        XCTAssertEqual(store.progress(for: store.cards[0].id).total, 2)
        XCTAssertEqual(store.progress(for: store.cards[1].id).position, 2)
    }

    // MARK: Another copy of a card the user already has

    func testAnotherCopyOfACardAlreadyAddedCanBePicked() throws {
        let store = try storeOnReview()
        let unlimited = try card("us-chase-freedom-unlimited")
        store.startAddingCards()

        XCTAssertEqual(store.lockedCount(of: unlimited), 1)
        store.increaseCount(of: unlimited)

        XCTAssertEqual(store.count(of: unlimited), 2)
        XCTAssertEqual(store.newPickCount, 1)
    }

    func testCardsAlreadyAddedCannotBeRemovedOnThePickScreen() throws {
        let store = try storeOnReview()
        let unlimited = try card("us-chase-freedom-unlimited")
        store.startAddingCards()
        store.increaseCount(of: unlimited)

        store.decreaseCount(of: unlimited)
        store.decreaseCount(of: unlimited)
        XCTAssertEqual(store.count(of: unlimited), 1, "the copy already added stays")

        store.toggleSelection(of: unlimited)
        XCTAssertTrue(store.isSelected(unlimited), "a locked card cannot be unticked")
        XCTAssertEqual(store.newPickCount, 0)
    }

    func testTheNewCopyGetsItsOwnFormAndTheOldOneKeepsItsDetails() throws {
        let store = try storeOnReview()
        let unlimited = try card("us-chase-freedom-unlimited")
        let original = store.cards[0]
        store.startAddingCards()
        store.increaseCount(of: unlimited)

        store.continueFromAddCards()

        XCTAssertEqual(store.cards.count, 3)
        XCTAssertEqual(store.cards[0].id, original.id)
        XCTAssertEqual(store.cards[0].details, original.details)
        XCTAssertEqual(store.cards[1].catalogCard.id, unlimited.id)
        XCTAssertEqual(store.addBatch, [store.cards[1].id])
        XCTAssertEqual(store.path.last, .cardForm(store.cards[1].id))
        XCTAssertEqual(store.progress(for: store.cards[1].id).position, 1)
        XCTAssertEqual(store.progress(for: store.cards[1].id).total, 1)
        XCTAssertEqual(store.title(of: store.cards[0]), "Chase Freedom Unlimited #1")
        XCTAssertEqual(store.title(of: store.cards[1]), "Chase Freedom Unlimited #2")

        store.advance(from: store.cards[1].id)
        XCTAssertEqual(store.path.last, .review)
        XCTAssertTrue(store.lockedCounts.isEmpty, "nothing is locked once adding is finished")
    }
}

