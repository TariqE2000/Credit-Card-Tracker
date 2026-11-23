import XCTest
@testable import CreditCardTracker

// MARK: - Models

final class DueDateTests: XCTestCase {
    func testValidDate() {
        let date = DueDate(month: 12, day: 14)
        XCTAssertEqual(date?.month, 12)
        XCTAssertEqual(date?.day, 14)
        XCTAssertEqual(date?.shortDescription, "Dec 14")
    }

    func testRejectsImpossibleDates() {
        XCTAssertNil(DueDate(month: 13, day: 1))
        XCTAssertNil(DueDate(month: 0, day: 1))
        XCTAssertNil(DueDate(month: 4, day: 31))
        XCTAssertNil(DueDate(month: 2, day: 30))
        XCTAssertNotNil(DueDate(month: 2, day: 29))
    }

    func testReadsFourDigits() {
        XCTAssertEqual(DueDate(digits: "1214"), DueDate(month: 12, day: 14))
        XCTAssertEqual(DueDate(digits: "0105"), DueDate(month: 1, day: 5))
        XCTAssertNil(DueDate(digits: "124"))
        XCTAssertNil(DueDate(digits: "1314"))
        XCTAssertNil(DueDate(digits: "12a4"))
        XCTAssertEqual(DueDate(month: 3, day: 7)?.digits, "0307")
    }
}

final class CardDetailsTests: XCTestCase {
    func testEmptyDetailsAreIncomplete() {
        XCTAssertFalse(CardDetails().isComplete)
    }

    func testAprIsNotRequired() {
        let details = CardDetails(
            balance: 100,
            minimumPayment: 25,
            dueDate: DueDate(month: 1, day: 1),
            apr: nil
        )
        XCTAssertTrue(details.isComplete)
    }

    func testMissingDueDateIsIncomplete() {
        let details = CardDetails(balance: 100, minimumPayment: 25, dueDate: nil, apr: 24.99)
        XCTAssertFalse(details.isComplete)
    }

    func testTotalBalanceSkipsIncompleteCards() throws {
        let complete = TrackedCard(
            catalogCard: try XCTUnwrap(BuiltInIssuers.card(withID: "us-chase-freedom-unlimited")),
            details: CardDetails(balance: 2480.15, minimumPayment: 45, dueDate: DueDate(month: 12, day: 14), apr: 24.99)
        )
        let incomplete = TrackedCard(
            catalogCard: try XCTUnwrap(BuiltInIssuers.card(withID: "us-chase-sapphire-preferred")),
            details: CardDetails(balance: 900)
        )
        XCTAssertEqual([complete, incomplete].totalBalance, 2480.15)
    }
}

final class IssuerCatalogTests: XCTestCase {
    func testEmptyQueryReturnsEverything() {
        XCTAssertEqual(BuiltInIssuers.cards(matching: "  ").count, BuiltInIssuers.all.count)
    }

    func testSearchMatchesNameOrIssuer() {
        XCTAssertTrue(BuiltInIssuers.cards(matching: "sapphire").contains { $0.id == "us-chase-sapphire-preferred" })
        XCTAssertTrue(BuiltInIssuers.cards(matching: "american express").allSatisfy { $0.issuer == "American Express" })
        XCTAssertTrue(BuiltInIssuers.cards(matching: "zzzz").isEmpty)
    }

    func testIDsAreUnique() {
        XCTAssertEqual(Set(BuiltInIssuers.all.map(\.id)).count, BuiltInIssuers.all.count)
    }
}

// MARK: - Store

@MainActor
final class OnboardingStoreTests: XCTestCase {
    private func card(_ id: String) throws -> Issuer {
        try XCTUnwrap(BuiltInIssuers.card(withID: id))
    }

    /// A store with two cards picked and the first card's form open.
    private func storeWithTwoCards() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("us-chase-freedom-unlimited"))
        store.toggleSelection(of: try card("us-chase-sapphire-preferred"))
        store.continueFromPickCards()
        return store
    }

    func testSignInOpensPickCards() {
        let store = OnboardingStore()
        store.signIn(with: .google)
        XCTAssertTrue(store.isSignedIn)
        XCTAssertEqual(store.path, [.pickCards])
    }

    func testToggleSelection() throws {
        let store = OnboardingStore()
        let chase = try card("us-chase-freedom-flex")
        store.toggleSelection(of: chase)
        XCTAssertTrue(store.isSelected(chase))
        XCTAssertEqual(store.selectedCount, 1)
        store.toggleSelection(of: chase)
        XCTAssertFalse(store.isSelected(chase))
        XCTAssertEqual(store.selectedCount, 0)
    }

    func testContinueWithNoCardsDoesNothing() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.continueFromPickCards()
        XCTAssertEqual(store.path, [.pickCards])
        XCTAssertTrue(store.cards.isEmpty)
    }

    func testContinueOpensFirstCardForm() throws {
        let store = try storeWithTwoCards()
        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.path, [.pickCards, .cardForm(store.cards[0].id)])
        XCTAssertEqual(store.position(of: store.cards[1].id), 2)
    }

    func testAdvanceWalksThroughCardsThenReview() throws {
        let store = try storeWithTwoCards()
        store.advance(from: store.cards[0].id)
        XCTAssertEqual(store.path.last, .cardForm(store.cards[1].id))
        store.advance(from: store.cards[1].id)
        XCTAssertEqual(store.path.last, .review)
    }

    func testDetailsSurviveGoingBackAndContinuingAgain() throws {
        let store = try storeWithTwoCards()
        let details = CardDetails(balance: 50, minimumPayment: 25, dueDate: DueDate(month: 1, day: 2))
        store.saveDetails(details, for: store.cards[0].id)

        // Pick a third card, then continue again.
        store.toggleSelection(of: try card("us-apple-card"))
        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 3)
        XCTAssertEqual(store.cards[0].details, details)
    }

    func testRemovingFirstCardShowsTheNextOne() throws {
        let store = try storeWithTwoCards()
        let secondID = store.cards[1].id
        store.removeCard(store.cards[0].id)
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.selectedCount, 1)
        XCTAssertEqual(store.path, [.pickCards, .cardForm(secondID)])
    }

    func testRemovingLastCardShowsReview() throws {
        let store = try storeWithTwoCards()
        store.advance(from: store.cards[0].id)
        store.removeCard(store.cards[1].id)
        XCTAssertEqual(store.path.last, .review)
    }

    func testRemovingEveryCardGoesBackToPicking() throws {
        let store = try storeWithTwoCards()
        store.removeCard(store.cards[0].id)
        store.removeCard(store.cards[0].id)
        XCTAssertTrue(store.cards.isEmpty)
        XCTAssertEqual(store.path, [.pickCards])
    }

    func testRemovingWhileEditingReturnsToReview() throws {
        let store = try storeWithTwoCards()
        store.advance(from: store.cards[0].id)
        store.advance(from: store.cards[1].id)
        store.path.append(.editCard(store.cards[0].id))
        store.removeCard(store.cards[0].id)
        XCTAssertEqual(store.path.last, .review)
        XCTAssertEqual(store.cards.count, 1)
    }

    func testFinishOnboardingClearsPath() throws {
        let store = try storeWithTwoCards()
        store.finishOnboarding()
        XCTAssertTrue(store.hasFinishedOnboarding)
        XCTAssertTrue(store.path.isEmpty)
    }
}
