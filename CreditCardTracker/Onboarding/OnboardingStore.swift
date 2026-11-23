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
    /// "Pick your cards" opened again from the review screen to add more cards.
    case addCards
}

/// Holds everything the onboarding screens share: where the user is, which cards they picked,
/// and the details they typed in.
@MainActor
final class OnboardingStore: ObservableObject {
    /// The cards the user can pick from. The app passes `CardCatalogStore.live()`. Without one, previews
    /// and tests get the built-in starter cards and never touch the network or the disk.
    let catalog: CardCatalogStore

    init(catalog: CardCatalogStore? = nil) {
        self.catalog = catalog ?? CardCatalogStore.builtIn()
    }

    @Published var path: [OnboardingRoute] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var hasFinishedOnboarding = false

    /// Catalog IDs in the order the user tapped them. Cards added with "My card is not listed" are in here too.
    @Published private(set) var selectedCatalogIDs: [String] = []
    /// The picked cards with their details. Rebuilt each time the user continues from "Pick your cards".
    @Published private(set) var cards: [TrackedCard] = []

    /// Catalog IDs of the cards the user already had when they tapped "Add another card". They show
    /// as ticked and cannot be changed on the second pick screen.
    @Published private(set) var lockedCatalogIDs: Set<String> = []
    /// The cards added with "Add another card", in order. Only these get a form on the way back to
    /// the review screen. Empty the rest of the time.
    @Published private(set) var addBatch: [UUID] = []

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

    // MARK: Cards that are not listed

    /// "My card is not listed": adds one more picked card. Its name is typed on its card form.
    func addNotListedCard() {
        selectedCatalogIDs.append(CatalogCard.customIDPrefix + UUID().uuidString)
    }

    /// Builds `cards` from the picked catalog entries, keeping any details already typed for cards
    /// that are still picked, and opens the form for the first card.
    func continueFromPickCards() {
        rebuildCards()
        guard let first = cards.first else { return }
        path.append(.cardForm(first.id))
    }

    private func rebuildCards() {
        let existing = Dictionary(
            cards.map { ($0.catalogCard.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        cards = selectedCatalogIDs.compactMap { id -> TrackedCard? in
            if let card = existing[id] { return card }
            return resolvedCard(withID: id).map { TrackedCard(catalogCard: $0) }
        }
    }

    // MARK: Add another card (from the review screen)

    /// "Add another card": opens "Pick your cards" again with the current cards already ticked.
    func startAddingCards() {
        selectedCatalogIDs = cards.map(\.catalogCard.id)
        lockedCatalogIDs = Set(selectedCatalogIDs)
        addBatch = []
        path.append(.addCards)
    }

    /// True for a card the user already has. Only meaningful on the second pick screen.
    func isLocked(_ card: CatalogCard) -> Bool {
        lockedCatalogIDs.contains(card.id)
    }

    /// How many new cards are picked on the second pick screen.
    var newPickCount: Int {
        selectedCatalogIDs.filter { !lockedCatalogIDs.contains($0) }.count
    }

    /// Continue on the second pick screen: keeps every current card and its details, adds the new
    /// ones, and opens the form for the first new card.
    func continueFromAddCards() {
        rebuildCards()
        addBatch = cards
            .filter { !lockedCatalogIDs.contains($0.catalogCard.id) }
            .map(\.id)
        guard let first = addBatch.first else { return }
        path.append(.cardForm(first))
    }

    /// Back to the review screen that is already in the stack, closing the pick screen and the forms.
    private func finishAdding() {
        addBatch = []
        if let reviewIndex = path.lastIndex(of: .review) {
            path = Array(path.prefix(through: reviewIndex))
        } else {
            path.append(.review)
        }
    }

    private func resolvedCard(withID id: String) -> CatalogCard? {
        if let card = catalog.card(withID: id) ?? CardCatalog.card(withID: id) { return card }
        return id.hasPrefix(CatalogCard.customIDPrefix) ? CatalogCard.custom(id: id) : nil
    }

    // MARK: Card form

    func card(withID id: UUID) -> TrackedCard? {
        cards.first { $0.id == id }
    }

    /// Position of the card in the list, starting at 1 ("Card 1 of 2").
    func position(of id: UUID) -> Int? {
        cards.firstIndex { $0.id == id }.map { $0 + 1 }
    }

    /// "Card 1 of 2" for a form. While adding more cards from the review screen it counts only the
    /// new cards; otherwise it counts every card.
    func progress(for id: UUID) -> (position: Int, total: Int) {
        if let index = addBatch.firstIndex(of: id) {
            return (index + 1, addBatch.count)
        }
        let index = cards.firstIndex { $0.id == id } ?? 0
        return (index + 1, max(cards.count, 1))
    }

    func saveDetails(_ details: CardDetails, for id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }) else { return }
        cards[index].details = details
    }

    /// Sets the name of a not-listed card as the user types it. Catalog cards keep their names.
    func setCustomName(_ name: String, for id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }), cards[index].catalogCard.isCustom else { return }
        cards[index].catalogCard = CatalogCard.custom(id: cards[index].catalogCard.id, name: name)
    }

    /// Goes to the next card's form, or to the review screen after the last card.
    func advance(from id: UUID) {
        // Adding more cards: step through the new cards only, then return to the review screen.
        if let batchIndex = addBatch.firstIndex(of: id) {
            if batchIndex + 1 < addBatch.count {
                path.append(.cardForm(addBatch[batchIndex + 1]))
            } else {
                finishAdding()
            }
            return
        }

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

        if cards.isEmpty {
            // Nothing left: back to picking cards.
            addBatch = []
            path = [.pickCards]
            return
        }

        if let batchIndex = addBatch.firstIndex(of: id) {
            // Removing one of the cards being added: on to the next new card, or back to the review screen.
            addBatch.remove(at: batchIndex)
            if case .cardForm(id) = path.last {
                if batchIndex < addBatch.count {
                    path[path.count - 1] = .cardForm(addBatch[batchIndex])
                } else {
                    finishAdding()
                }
            }
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
