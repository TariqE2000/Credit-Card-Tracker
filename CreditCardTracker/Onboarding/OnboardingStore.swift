import Foundation

enum AuthProvider: String, Hashable {
    case google
    case apple
}

/// Every screen that can be pushed on top of the sign up screen.
enum OnboardingRoute: Hashable {
    case logIn
    case pickCards
    /// The form shown right after picking cards ("Card 1 of 2"). Moves on to the next card.
    case cardForm(UUID)
    /// The same form opened from the review screen. Saving goes back to the review screen.
    case editCard(UUID)
    case review
}

/// Holds everything the onboarding screens share: where the user is, which cards they picked,
/// and the details they typed in.
@MainActor
final class OnboardingStore: ObservableObject {
    @Published var path: [OnboardingRoute] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var hasFinishedOnboarding = false

    /// Catalog IDs in the order the user tapped them. Custom cards are in here too.
    @Published private(set) var selectedCatalogIDs: [String] = []
    /// Cards the user added with "My card is not listed". Always picked.
    @Published private(set) var customCards: [CatalogCard] = []
    /// The picked cards with their details. Rebuilt each time the user continues from "Pick your cards".
    @Published private(set) var cards: [TrackedCard] = []

    // MARK: Sign up and log in

    func signIn(with provider: AuthProvider) {
        // TODO(supabase): get an ID token from Apple / Google and exchange it for a Supabase session.
        // Until that exists, signing in just moves on. Sign up and log in behave the same for now.
        isSignedIn = true
        path = [.pickCards]
    }

    func showLogIn() {
        path = [.logIn]
    }

    func showSignUp() {
        path = []
    }

    // MARK: Pick your cards

    var selectedCount: Int { selectedCatalogIDs.count }

    func isSelected(_ card: CatalogCard) -> Bool {
        selectedCatalogIDs.contains(card.id)
    }

    func toggleSelection(of card: CatalogCard) {
        if let index = selectedCatalogIDs.firstIndex(of: card.id) {
            selectedCatalogIDs.remove(at: index)
        } else {
            selectedCatalogIDs.append(card.id)
        }
    }

    // MARK: Custom cards

    /// "My card is not listed": adds a picked card with no name yet, for the user to name.
    @discardableResult
    func addCustomCard() -> CatalogCard {
        let card = CatalogCard.custom(name: "")
        customCards.append(card)
        selectedCatalogIDs.append(card.id)
        return card
    }

    func renameCustomCard(_ id: String, to name: String) {
        guard let index = customCards.firstIndex(where: { $0.id == id }) else { return }
        customCards[index] = CatalogCard.custom(id: id, name: name)
    }

    func removeCustomCard(_ id: String) {
        customCards.removeAll { $0.id == id }
        selectedCatalogIDs.removeAll { $0 == id }
    }

    /// True while a custom card has no name. The user has to name it before continuing.
    var hasUnnamedCustomCard: Bool {
        customCards.contains { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var canContinueFromPickCards: Bool {
        selectedCount > 0 && !hasUnnamedCustomCard
    }

    /// The catalog card or custom card for an ID. Custom card names are tidied of extra spaces.
    private func resolvedCard(withID id: String) -> CatalogCard? {
        if let card = CardCatalog.card(withID: id) { return card }
        guard let custom = customCards.first(where: { $0.id == id }) else { return nil }
        return CatalogCard.custom(id: id, name: custom.name.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// Builds `cards` from the picked catalog entries, keeping any details already typed for cards
    /// that are still picked, and opens the form for the first card.
    func continueFromPickCards() {
        guard !hasUnnamedCustomCard else { return }

        let existing = Dictionary(
            cards.map { ($0.catalogCard.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        cards = selectedCatalogIDs.compactMap { id -> TrackedCard? in
            guard let catalogCard = resolvedCard(withID: id) else { return nil }
            guard let old = existing[id] else { return TrackedCard(catalogCard: catalogCard) }
            // Keep what was typed, but pick up a custom card that was renamed in the meantime.
            return TrackedCard(id: old.id, catalogCard: catalogCard, details: old.details)
        }
        guard let first = cards.first else { return }
        path.append(.cardForm(first.id))
    }

    // MARK: Card form

    func card(withID id: UUID) -> TrackedCard? {
        cards.first { $0.id == id }
    }

    /// Position of the card in the list, starting at 1 ("Card 1 of 2").
    func position(of id: UUID) -> Int? {
        cards.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    func saveDetails(_ details: CardDetails, for id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].details = details
    }

    /// Goes to the next card's form, or to the review screen after the last card.
    func advance(from id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        if index + 1 < cards.count {
            path.append(.cardForm(cards[index + 1].id))
        } else {
            path.append(.review)
        }
    }

    /// Removes a card from the list (and from the picked cards) and shows whatever should come next.
    func removeCard(_ id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        let removed = cards.remove(at: index)
        selectedCatalogIDs.removeAll { $0 == removed.catalogCard.id }
        customCards.removeAll { $0.id == removed.catalogCard.id }

        if cards.isEmpty {
            // Nothing left: back to picking cards.
            path = [.pickCards]
            return
        }

        switch path.last {
        case .cardForm(id):
            // Swap this form for the next card's form, or the review screen if this was the last card.
            path[path.count - 1] = index < cards.count ? .cardForm(cards[index].id) : .review
        case .editCard(id):
            // Editing from the review screen: just go back to it.
            path.removeLast()
        default:
            break
        }
    }

    // MARK: Review

    func finishOnboarding() {
        // TODO(supabase): save the cards to the user's account.
        hasFinishedOnboarding = true
        path = []
    }
}
