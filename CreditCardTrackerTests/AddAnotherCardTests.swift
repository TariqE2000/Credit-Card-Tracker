import XCTest
@testable import CreditCardTracker

/// "Add another card" on the review screen: pick more cards, fill in only the new ones, land back on review.
@MainActor
final class AddAnotherCardTests: XCTestCase {
    private func issuer(_ id: String) throws -> Issuer {
        try XCTUnwrap(BuiltInIssuers.issuer(withID: id))
    }

    /// Two Chase cards picked, the first one filled in, and the review screen open.
    private func storeOnReview() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try issuer("chase"))
        store.increaseCount(of: try issuer("chase"))
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

    func testAddAnotherCardOpensPickCardsWithCurrentCardsCounted() throws {
        let store = try storeOnReview()
        store.startAddingCards()

        XCTAssertEqual(store.path.last, .addCards)
        XCTAssertTrue(store.isSelected(try issuer("chase")))
        XCTAssertEqual(store.count(of: try issuer("chase")), 2)
        XCTAssertEqual(store.lockedCount(of: try issuer("chase")), 2)
        XCTAssertEqual(store.lockedCount(of: try issuer("amex")), 0)
        XCTAssertEqual(store.newPickCount, 0)
    }

    func testOnlyNewCardsAreCounted() throws {
        let store = try storeOnReview()
        store.startAddingCards()

        store.toggleSelection(of: try issuer("amex"))
        store.addNotListedCard()

        XCTAssertEqual(store.newPickCount, 2)
        XCTAssertEqual(store.selectedCount, 4)
    }

    func testAnotherCardFromAnIssuerTheUserAlreadyHas() throws {
        let store = try storeOnReview()
        let existing = Array(store.cards)
        store.startAddingCards()

        store.increaseCount(of: try issuer("chase"))
        XCTAssertEqual(store.newPickCount, 1)

        store.continueFromAddCards()

        XCTAssertEqual(store.cards.count, 3)
        XCTAssertEqual(Array(store.cards.prefix(2)), existing, "the first two keep their details")
        XCTAssertEqual(store.cards[2].issuer.id, "chase")
        XCTAssertEqual(store.title(of: store.cards[2]), "Chase 3")
        XCTAssertEqual(store.addBatch, [store.cards[2].id])
        XCTAssertEqual(store.path.last, .cardForm(store.cards[2].id))
        XCTAssertEqual(store.progress(for: store.cards[2].id).position, 1)
        XCTAssertEqual(store.progress(for: store.cards[2].id).total, 1)
    }

    func testCardsAlreadyAddedCannotBeCountedAway() throws {
        let store = try storeOnReview()
        store.startAddingCards()
        let chase = try issuer("chase")
        let owned = store.lockedCount(of: chase)

        store.increaseCount(of: chase)
        XCTAssertEqual(store.count(of: chase), 3)

        // The screen passes the number of cards already added as the minimum.
        store.decreaseCount(of: chase, minimum: owned)
        XCTAssertEqual(store.count(of: chase), 2)
        store.decreaseCount(of: chase, minimum: owned)
        XCTAssertEqual(store.count(of: chase), 2)
        XCTAssertEqual(store.newPickCount, 0)
    }

    func testContinueKeepsCurrentCardsAndOpensTheFirstNewCard() throws {
        let store = try storeOnReview()
        let firstCard = store.cards[0]
        store.startAddingCards()
        store.toggleSelection(of: try issuer("amex"))
        store.addNotListedCard()

        store.continueFromAddCards()

        XCTAssertEqual(store.cards.count, 4)
        XCTAssertEqual(store.cards[0], firstCard)
        XCTAssertEqual(store.cards[2].issuer.id, "amex")
        XCTAssertTrue(store.cards[3].issuer.isCustom)
        XCTAssertEqual(store.path.last, .cardForm(store.cards[2].id))

        // "Card 1 of 2" counts the new cards only.
        XCTAssertEqual(store.progress(for: store.cards[2].id).position, 1)
        XCTAssertEqual(store.progress(for: store.cards[2].id).total, 2)
        XCTAssertEqual(store.progress(for: store.cards[3].id).position, 2)
    }

    func testFinishingTheLastNewCardReturnsToTheReviewScreen() throws {
        let store = try storeOnReview()
        store.startAddingCards()
        store.toggleSelection(of: try issuer("amex"))
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
        store.toggleSelection(of: try issuer("amex"))
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
        store.toggleSelection(of: try issuer("amex"))
        store.increaseCount(of: try issuer("chase"))
        XCTAssertEqual(store.newPickCount, 2)

        // Back to the review screen without continuing, then "Add another card" again.
        store.path.removeLast()
        store.startAddingCards()

        XCTAssertEqual(store.newPickCount, 0)
        XCTAssertFalse(store.isSelected(try issuer("amex")))
        XCTAssertEqual(store.count(of: try issuer("chase")), 2)
        XCTAssertEqual(store.cards.count, 2)
    }

    func testFirstPassFormsStillCountEveryCard() throws {
        let store = OnboardingStore()
        store.toggleSelection(of: try issuer("chase"))
        store.toggleSelection(of: try issuer("amex"))
        store.continueFromPickCards()

        XCTAssertEqual(store.progress(for: store.cards[0].id).position, 1)
        XCTAssertEqual(store.progress(for: store.cards[0].id).total, 2)
        XCTAssertEqual(store.progress(for: store.cards[1].id).position, 2)
    }
}
