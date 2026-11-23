import XCTest
@testable import CreditCardTracker

final class CustomCardModelTests: XCTestCase {
    func testInitials() {
        XCTAssertEqual(CatalogCard.initials(for: ""), "?")
        XCTAssertEqual(CatalogCard.initials(for: "   "), "?")
        XCTAssertEqual(CatalogCard.initials(for: "Costco"), "CO")
        XCTAssertEqual(CatalogCard.initials(for: "Navy Federal Visa"), "NF")
        XCTAssertEqual(CatalogCard.initials(for: "x"), "X")
    }

    func testCustomCardsAreMarkedCustom() {
        XCTAssertTrue(CatalogCard.custom(name: "My Bank").isCustom)
        XCTAssertFalse(CardCatalog.all[0].isCustom)
    }

    func testEachCustomCardGetsItsOwnID() {
        XCTAssertNotEqual(CatalogCard.custom(name: "").id, CatalogCard.custom(name: "").id)
    }
}

@MainActor
final class CustomCardStoreTests: XCTestCase {
    func testAddingACustomCardCountsAsPicked() {
        let store = OnboardingStore()
        store.toggleSelection(of: CardCatalog.all[0])

        let card = store.addCustomCard()

        XCTAssertEqual(store.selectedCount, 2)
        XCTAssertTrue(store.isSelected(card))
        XCTAssertEqual(store.customCards.count, 1)
        XCTAssertEqual(card.name, "")
        XCTAssertEqual(card.badgeCode, "?")
    }

    func testCustomCardMustBeNamedBeforeContinuing() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let card = store.addCustomCard()

        XCTAssertTrue(store.hasUnnamedCustomCard)
        XCTAssertFalse(store.canContinueFromPickCards)
        store.continueFromPickCards()
        XCTAssertEqual(store.path, [.pickCards])
        XCTAssertTrue(store.cards.isEmpty)

        store.renameCustomCard(card.id, to: "   ")
        XCTAssertTrue(store.hasUnnamedCustomCard)

        store.renameCustomCard(card.id, to: "Navy Federal")
        XCTAssertFalse(store.hasUnnamedCustomCard)
        XCTAssertTrue(store.canContinueFromPickCards)
        XCTAssertEqual(store.customCards.first?.badgeCode, "NF")
    }

    func testContinueUsesTheTrimmedName() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let card = store.addCustomCard()
        store.renameCustomCard(card.id, to: "  Navy Federal  ")

        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].catalogCard.name, "Navy Federal")
        XCTAssertEqual(store.cards[0].catalogCard.issuer, "Custom card")
        XCTAssertEqual(store.path.last, .cardForm(store.cards[0].id))
    }

    func testRenamingAfterContinuingKeepsDetails() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let card = store.addCustomCard()
        store.renameCustomCard(card.id, to: "Credit Union")
        store.continueFromPickCards()

        let id = store.cards[0].id
        let details = CardDetails(balance: 100, minimumPayment: 25, dueDate: DueDate(month: 3, day: 9))
        store.saveDetails(details, for: id)

        store.renameCustomCard(card.id, to: "Credit Union Visa")
        store.continueFromPickCards()

        XCTAssertEqual(store.cards.count, 1)
        XCTAssertEqual(store.cards[0].id, id)
        XCTAssertEqual(store.cards[0].catalogCard.name, "Credit Union Visa")
        XCTAssertEqual(store.cards[0].details, details)
    }

    func testRemovingACustomCardFromTheList() {
        let store = OnboardingStore()
        let card = store.addCustomCard()

        store.removeCustomCard(card.id)

        XCTAssertEqual(store.selectedCount, 0)
        XCTAssertTrue(store.customCards.isEmpty)
    }

    func testRemovingACustomCardFromItsFormForgetsIt() {
        let store = OnboardingStore()
        store.signIn(with: .apple)
        let card = store.addCustomCard()
        store.renameCustomCard(card.id, to: "Credit Union")
        store.toggleSelection(of: CardCatalog.all[0])
        store.continueFromPickCards()

        store.removeCard(store.cards[0].id)

        XCTAssertTrue(store.customCards.isEmpty)
        XCTAssertEqual(store.selectedCount, 1)
        XCTAssertEqual(store.cards.count, 1)
    }
}
