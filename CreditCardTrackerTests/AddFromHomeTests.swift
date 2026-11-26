import XCTest
@testable import CreditCardTracker

/// The "+" button on the home screen: pick new cards in a sheet, fill in a form for each, and the sheet closes.
@MainActor
final class AddFromHomeTests: XCTestCase {
    private func card(_ id: String) throws -> CatalogCard {
        try XCTUnwrap(CardCatalog.card(withID: id))
    }

    /// A store where onboarding is finished with two cards, like the home screen.
    private func finishedStore() throws -> OnboardingStore {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("us-chase-freedom-unlimited"))
        store.toggleSelection(of: try card("us-chase-sapphire-preferred"))
        store.continueFromPickCards()
        store.finishOnboarding()
        return store
    }

    func testPlusOpensThePickerWithCurrentCardsLocked() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        XCTAssertTrue(store.isAddingFromHome)
        XCTAssertEqual(store.path, [])
        XCTAssertTrue(store.isLocked(store.cards[0].catalogCard))
        XCTAssertTrue(store.isLocked(store.cards[1].catalogCard))
        XCTAssertEqual(store.newPickCount, 0)
    }

    func testPickingANewCardOpensItsForm() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        let flex = try card("us-chase-freedom-flex")
        store.toggleSelection(of: flex)
        XCTAssertEqual(store.newPickCount, 1)

        store.continueFromAddCards()
        XCTAssertEqual(store.cards.count, 3)
        let added = try XCTUnwrap(store.cards.last)
        XCTAssertEqual(added.catalogCard.id, flex.id)
        XCTAssertEqual(store.path, [.cardForm(added.id)])
        XCTAssertEqual(store.progress(for: added.id).total, 1)
    }

    func testSavingTheLastFormClosesTheSheet() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.continueFromAddCards()
        let added = try XCTUnwrap(store.cards.last)

        store.advance(from: added.id)
        XCTAssertFalse(store.isAddingFromHome)
        XCTAssertEqual(store.path, [])
        XCTAssertTrue(store.addBatch.isEmpty)
        // The review screen is never pushed.
        XCTAssertFalse(store.path.contains(.review))
    }

    func testFormsStepThroughOnlyTheNewCards() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.addNotListedCard()
        store.continueFromAddCards()
        XCTAssertEqual(store.cards.count, 4)

        let first = store.addBatch[0]
        let second = store.addBatch[1]
        XCTAssertEqual(store.progress(for: first).total, 2)
        store.advance(from: first)
        XCTAssertEqual(store.path.last, .cardForm(second))
        XCTAssertTrue(store.isAddingFromHome)
        store.advance(from: second)
        XCTAssertFalse(store.isAddingFromHome)
    }

    func testCancellingDropsPicksThatNeverGotAForm() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.cancelAddingFromHome()
        XCTAssertFalse(store.isAddingFromHome)
        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.selectedCount, 2)
        XCTAssertEqual(store.path, [])
    }

    func testCancellingInsideAFormKeepsTheCardForLater() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.continueFromAddCards()
        store.cancelAddingFromHome()
        XCTAssertFalse(store.isAddingFromHome)
        // The new card is on the home screen without details, ready for "Add details".
        XCTAssertEqual(store.cards.count, 3)
        XCTAssertFalse(try XCTUnwrap(store.cards.last).detailsComplete)
        XCTAssertEqual(store.selectedCount, 3)
    }

    func testRemovingTheOnlyNewCardClosesTheSheet() throws {
        let store = try finishedStore()
        store.startAddingFromHome()
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.continueFromAddCards()
        let added = try XCTUnwrap(store.cards.last)

        store.removeCard(added.id)
        XCTAssertFalse(store.isAddingFromHome)
        XCTAssertEqual(store.cards.count, 2)
        XCTAssertEqual(store.path, [])
    }

    func testPlusWorksWithNoCardsYet() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.continueFromPickCards()
        let only = try XCTUnwrap(store.cards.first)
        store.finishOnboarding()
        store.removeCard(only.id)
        XCTAssertTrue(store.cards.isEmpty)

        store.startAddingFromHome()
        XCTAssertEqual(store.path, [])
        store.toggleSelection(of: try card("us-chase-sapphire-preferred"))
        store.continueFromAddCards()
        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.progress(for: store.cards[0].id).total, 1)
    }

    func testRemovingTheLastCardInsideTheSheetGoesBackToThePicker() throws {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        store.toggleSelection(of: try card("us-chase-freedom-flex"))
        store.continueFromPickCards()
        let only = try XCTUnwrap(store.cards.first)
        store.finishOnboarding()
        store.removeCard(only.id)

        store.startAddingFromHome()
        store.toggleSelection(of: try card("us-chase-sapphire-preferred"))
        store.continueFromAddCards()
        store.removeCard(store.cards[0].id)
        XCTAssertTrue(store.isAddingFromHome)
        XCTAssertEqual(store.path, [])
    }
}
