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

/// Limits for picking several copies of the same card.
enum CardCopies {
    /// The most copies of one card the "+" button allows.
    static let maximum = 10
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

    /// Catalog IDs in the order the user tapped them. A card the user has two of is in here twice, next to
    /// each other. Cards added with "My card is not listed" are in here too.
    @Published private(set) var selectedCatalogIDs: [String] = []
    /// The picked cards with their details. Rebuilt each time the user continues from "Pick your cards".
    @Published private(set) var cards: [TrackedCard] = []

    /// How many copies of each card the user already had when they tapped "Add another card", by catalog ID.
    /// Those show as ticked and cannot be removed on the second pick screen; the user can add more copies.
    @Published private(set) var lockedCounts: [String: Int] = [:]
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

    /// Every picked copy of every card.
    var selectedCount: Int { selectedCatalogIDs.count }

    /// How many copies of this card are picked. 0 means the card is not ticked.
    func count(of card: CatalogCard) -> Int {
        selectedCatalogIDs.filter { $0 == card.id }.count
    }

    func isSelected(_ card: CatalogCard) -> Bool {
        selectedCatalogIDs.contains(card.id)
    }

    /// Ticks a card (one copy), or unticks it (every copy). A card the user already added cannot be unticked.
    func toggleSelection(of card: CatalogCard) {
        if isSelected(card) {
            guard !isLocked(card) else { return }
            selectedCatalogIDs.removeAll { $0 == card.id }
        } else {
            selectedCatalogIDs.append(card.id)
        }
    }

    /// The "+" button: one more copy of a ticked card, up to `CardCopies.maximum`. It goes next to the other copies.
    func increaseCount(of card: CatalogCard) {
        guard let last = selectedCatalogIDs.lastIndex(of: card.id), count(of: card) < CardCopies.maximum else { return }
        selectedCatalogIDs.insert(card.id, at: last + 1)
    }

    /// The "−" button: one copy fewer, but never below 1 (unticking is the checkbox's job) and never
    /// below the copies the user already added.
    func decreaseCount(of card: CatalogCard) {
        guard count(of: card) > max(lockedCount(of: card), 1),
              let last = selectedCatalogIDs.lastIndex(of: card.id)
        else { return }
        selectedCatalogIDs.remove(at: last)
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

    /// One card for each picked copy. A card that already exists keeps its details: when a card has two
    /// copies, the first copy matches the first existing card, the second matches the second, and so on.
    /// If the count goes down, the first copies survive.
    private func rebuildCards() {
        var existing = Dictionary(grouping: cards, by: { $0.catalogCard.id })
        cards = selectedCatalogIDs.compactMap { id -> TrackedCard? in
            if var kept = existing[id], !kept.isEmpty {
                let card = kept.removeFirst()
                existing[id] = kept
                return card
            }
            return resolvedCard(withID: id).map { TrackedCard(catalogCard: $0) }
        }
    }

    // MARK: Add another card (from the review screen)

    /// "Add another card": opens "Pick your cards" again with the current cards already ticked.
    func startAddingCards() {
        selectedCatalogIDs = cards.map(\.catalogCard.id)
        lockedCounts = Dictionary(selectedCatalogIDs.map { ($0, 1) }, uniquingKeysWith: +)
        addBatch = []
        path.append(.addCards)
    }

    /// How many copies of this card the user already had when the second pick screen opened.
    func lockedCount(of card: CatalogCard) -> Int {
        lockedCounts[card.id] ?? 0
    }

    /// True for a card the user already has. Only meaningful on the second pick screen.
    func isLocked(_ card: CatalogCard) -> Bool {
        lockedCount(of: card) > 0
    }

    /// How many new cards are picked on the second pick screen: copies beyond the ones already added.
    var newPickCount: Int {
        let picked = Dictionary(selectedCatalogIDs.map { ($0, 1) }, uniquingKeysWith: +)
        return picked.reduce(0) { $0 + max(0, $1.value - (lockedCounts[$1.key] ?? 0)) }
    }

    /// Continue on the second pick screen: keeps every current card and its details, adds the new
    /// ones, and opens the form for the first new card.
    func continueFromAddCards() {
        let existingIDs = Set(cards.map(\.id))
        rebuildCards()
        addBatch = cards.filter { !existingIDs.contains($0.id) }.map(\.id)
        guard let first = addBatch.first else { return }
        path.append(.cardForm(first))
    }

    /// Back to the review screen that is already in the stack, closing the pick screen and the forms.
    private func finishAdding() {
        addBatch = []
        lockedCounts = [:]
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

    /// What to call a card on screen: its name, with a number when the user has several copies of it
    /// ("Chase Sapphire Preferred #1", "Chase Sapphire Preferred #2").
    func title(of card: TrackedCard) -> String {
        let name = card.catalogCard.displayName
        let copies = cards.filter { $0.catalogCard.id == card.catalogCard.id }
        guard copies.count > 1, let index = copies.firstIndex(where: { $0.id == card.id }) else {
            return name
        }
        return "\(name) #\(index + 1)"
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
        // Which copy this is (0 for the first), so only that copy is dropped from the picks.
        let copyNumber = cards[..<index].filter { $0.catalogCard.id == cards[index].catalogCard.id }.count
        let removed = cards.remove(at: index)
        removePick(ofCatalogID: removed.catalogCard.id, copyNumber: copyNumber)

        if cards.isEmpty {
            // Nothing left: back to picking cards.
            addBatch = []
            lockedCounts = [:]
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

    /// Drops one picked copy of a card: the `copyNumber`-th one, counting from 0.
    private func removePick(ofCatalogID id: String, copyNumber: Int) {
        let positions = selectedCatalogIDs.indices.filter { selectedCatalogIDs[$0] == id }
        let which = min(copyNumber, positions.count - 1)
        guard which >= 0 else { return }
        selectedCatalogIDs.remove(at: positions[which])
    }

    // MARK: Review

    func finishOnboarding() {
        // TODO(supabase): save the cards to the user's account.
        hasFinishedOnboarding = true
        path = []
    }
}
