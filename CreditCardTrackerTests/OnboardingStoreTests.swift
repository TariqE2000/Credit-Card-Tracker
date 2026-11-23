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
        let chase = try XCTUnwrap(BuiltInIssuers.issuer(withID: "chase"))
        let complete = TrackedCard(
            issuer: chase,
            details: CardDetails(balance: 2480.15, minimumPayment: 45, dueDate: DueDate(month: 12, day: 14), apr: 24.99)
        )
        let incomplete = TrackedCard(issuer: chase, details: CardDetails(balance: 900))
        XCTAssertEqual([complete, incomplete].totalBalance, 2480.15)
    }
}

final class BuiltInIssuersTests: XCTestCase {
    func testIDsAreUnique() {
        XCTAssertEqual(Set(BuiltInIssuers.all.map(\.id)).count, BuiltInIssuers.all.count)
    }

    func testLookupByID() {
        XCTAssertEqual(BuiltInIssuers.issuer(withID: "amex")?.name, "American Express")
        XCTAssertNil(BuiltInIssuers.issuer(withID: "nope"))
    }

    func testTheBigIssuersComeFirstInThePriorityOrder() {
        let firstTen = BuiltInIssuers.all.prefix(IssuerStyle.priorityIssuerIDs.count).map(\.id)
        XCTAssertEqual(firstTen, IssuerStyle.priorityIssuerIDs)
    }
}

// MARK: - Store

@MainActor
final class OnboardingStoreTests: XCTestCase {
    private func issuer(_ id: String) throws -> Issuer {
        try XCTUnwrap(BuiltInIssuers.issuer(withID: id))
    }

    /// A store with two cards from two issuers picked and the first card's form open.
    private func storeWithTwoCards() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try issuer("chase"))
        store.toggleSelection(of: try issuer("amex"))
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
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        XCTAssertTrue(store.isSelected(chase))
        XCTAssertEqual(store.count(of: chase), 1)
        XCTAssertEqual(store.selectedCount, 1)
        store.toggleSelection(of: chase)
        XCTAssertFalse(store.isSelected(chase))
        XCTAssertEqual(store.count(of: chase), 0)
        XCTAssertEqual(store.selectedCount, 0)
    }

    // MARK: Cards per issuer

    func testThePlusAndMinusButtonsChangeTheNumberOfCards() throws {
        let store = OnboardingStore()
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)

        store.increaseCount(of: chase)
        store.increaseCount(of: chase)
        XCTAssertEqual(store.count(of: chase), 3)
        XCTAssertEqual(store.selectedCount, 3)

        store.decreaseCount(of: chase)
        XCTAssertEqual(store.count(of: chase), 2)
    }

    func testMinusStopsAtOneBecauseUntickingIsTheCheckboxsJob() throws {
        let store = OnboardingStore()
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.decreaseCount(of: chase)
        store.decreaseCount(of: chase, minimum: 0)
        XCTAssertEqual(store.count(of: chase), 1)
        XCTAssertTrue(store.isSelected(chase))
    }

    func testPlusStopsAtTheLimit() throws {
        let store = OnboardingStore()
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        for _ in 0..<(IssuerPick.maxCount + 5) { store.increaseCount(of: chase) }
        XCTAssertEqual(store.count(of: chase), IssuerPick.maxCount)
    }

    func testPlusDoesNothingForAnIssuerThatIsNotTicked() throws {
        let store = OnboardingStore()
        let amex = try issuer("amex")
        store.increaseCount(of: amex)
        XCTAssertEqual(store.count(of: amex), 0)
        XCTAssertEqual(store.selectedCount, 0)
    }

    func testUntickingAnIssuerDropsAllItsCards() throws {
        let store = OnboardingStore()
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.increaseCount(of: chase)
        store.toggleSelection(of: chase)
        XCTAssertEqual(store.selectedCount, 0)

        // Ticking it again starts from one card.
        store.toggleSelection(of: chase)
        XCTAssertEqual(store.count(of: chase), 1)
    }

    func testEachCardGetsItsOwnForm() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.increaseCount(of: chase)
        store.toggleSelection(of: try issuer("amex"))

        store.continueFromPickCards()

        // Cards from one issuer sit together, in the order the issuers were picked.
        XCTAssertEqual(store.cards.map(\.issuer.id), ["chase", "chase", "amex"])
        XCTAssertEqual(Set(store.cards.map(\.id)).count, 3, "three different cards")
        XCTAssertEqual(store.path, [.pickCards, .cardForm(store.cards[0].id)])
        XCTAssertEqual(store.progress(for: store.cards[1].id).position, 2)
        XCTAssertEqual(store.progress(for: store.cards[1].id).total, 3)
    }

    func testCardsFromTheSameIssuerAreNumbered() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.increaseCount(of: chase)
        store.toggleSelection(of: try issuer("amex"))
        store.continueFromPickCards()

        XCTAssertEqual(store.title(of: store.cards[0]), "Chase 1")
        XCTAssertEqual(store.title(of: store.cards[1]), "Chase 2")
        XCTAssertEqual(store.title(of: store.cards[2]), "American Express", "a single card has no number")
    }

    func testRaisingTheCountKeepsTheDetailsAlreadyTyped() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.continueFromPickCards()
        let details = CardDetails(balance: 50, minimumPayment: 25, dueDate: DueDate(month: 1, day: 2))
        store.saveDetails(details, for: store.cards[0].id)
        let firstID = store.cards[0].id

        store.increaseCount(of: chase)
        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.cards[0].id, firstID)
        XCTAssertEqual(store.cards[0].details, details)
        XCTAssertEqual(store.cards[1].details, CardDetails())
    }

    func testLoweringTheCountKeepsTheFirstCardsAndTheirDetails() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.increaseCount(of: chase)
        store.continueFromPickCards()
        let first = CardDetails(balance: 10, minimumPayment: 5, dueDate: DueDate(month: 3, day: 4))
        let second = CardDetails(balance: 20, minimumPayment: 5, dueDate: DueDate(month: 5, day: 6))
        store.saveDetails(first, for: store.cards[0].id)
        store.saveDetails(second, for: store.cards[1].id)

        store.decreaseCount(of: chase)
        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].details, first)
    }

    func testRemovingACardLowersItsIssuersCount() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let chase = try issuer("chase")
        store.toggleSelection(of: chase)
        store.increaseCount(of: chase)
        store.continueFromPickCards()

        store.removeCard(store.cards[0].id)
        XCTAssertEqual(store.count(of: chase), 1)
        XCTAssertEqual(store.cards.count, 1)

        store.removeCard(store.cards[0].id)
        XCTAssertFalse(store.isSelected(chase))
        XCTAssertEqual(store.path, [.pickCards])
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
        store.toggleSelection(of: try issuer("citi"))
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
