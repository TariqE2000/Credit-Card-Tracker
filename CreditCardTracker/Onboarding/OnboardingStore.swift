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

/// One row of "Pick your cards": an issuer and how many cards the user has from it.
struct IssuerPick: Hashable {
    let issuerID: String
    var count: Int

    /// Nobody needs more than this many cards from one issuer, and it keeps the counter sensible.
    static let maxCount = 10
}

/// Holds everything the onboarding screens share: where the user is, which issuers they picked and how
/// many cards each has, and the details they typed in for every card.
@MainActor
final class OnboardingStore: ObservableObject {
    /// The issuers the user can pick from. The app passes `IssuerCatalogStore.live()`. Without one,
    /// previews and tests get the built-in starter issuers and never touch the network or the disk.
    let catalog: IssuerCatalogStore

    init(catalog: IssuerCatalogStore? = nil) {
        self.catalog = catalog ?? IssuerCatalogStore.builtIn()
    }

    @Published var path: [OnboardingRoute] = []
    @Published private(set) var isSignedIn = false
    @Published private(set) var hasFinishedOnboarding = false

    /// The picked issuers in the order the user first tapped them, each with its number of cards. A bank
    /// added with "My bank is not listed" is in here too, with one card.
    @Published private(set) var picks: [IssuerPick] = []
    /// The cards, one per card the user has, with their details. Cards from the same issuer sit next to
    /// each other. Rebuilt each time the user continues from "Pick your cards".
    @Published private(set) var cards: [TrackedCard] = []

    /// How many cards the user already had from each issuer when they tapped "Add another card"
    /// (issuer ID to count). Those cards cannot be taken away on the second pick screen, but more can
    /// be added. Only meaningful on that screen.
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

    /// Cards picked in total, across every issuer.
    var selectedCount: Int { picks.reduce(0) { $0 + $1.count } }

    /// How many cards the user has from this issuer. 0 when it is not ticked.
    func count(of issuer: Issuer) -> Int {
        picks.first { $0.issuerID == issuer.id }?.count ?? 0
    }

    func isSelected(_ issuer: Issuer) -> Bool {
        count(of: issuer) > 0
    }

    /// Ticks an issuer (one card) or unticks it (no cards).
    func toggleSelection(of issuer: Issuer) {
        if let index = picks.firstIndex(where: { $0.issuerID == issuer.id }) {
            picks.remove(at: index)
        } else {
            picks.append(IssuerPick(issuerID: issuer.id, count: 1))
        }
    }

    /// The "+" button: one more card from a ticked issuer, up to `IssuerPick.maxCount`.
    func increaseCount(of issuer: Issuer) {
        guard let index = picks.firstIndex(where: { $0.issuerID == issuer.id }),
              picks[index].count < IssuerPick.maxCount
        else { return }
        picks[index].count += 1
    }

    /// The "−" button: one card fewer, but never below `minimum` (and never below 1; unticking is the
    /// checkbox's job). On the second pick screen `minimum` is the number of cards already added.
    func decreaseCount(of issuer: Issuer, minimum: Int = 1) {
        guard let index = picks.firstIndex(where: { $0.issuerID == issuer.id }),
              picks[index].count > max(minimum, 1)
        else { return }
        picks[index].count -= 1
    }

    // MARK: Banks that are not listed

    /// "My bank is not listed": adds one more card, from a bank whose name is typed on the card form.
    func addNotListedCard() {
        picks.append(IssuerPick(issuerID: Issuer.customIDPrefix + UUID().uuidString, count: 1))
    }

    /// Builds `cards` from the picks, keeping any details already typed for cards that are still
    /// picked, and opens the form for the first card.
    func continueFromPickCards() {
        rebuildCards()
        guard let first = cards.first else { return }
        path.append(.cardForm(first.id))
    }

    /// One card for each count of each pick. A card that already exists is kept with its details; the
    /// first `count` cards of an issuer survive when its count goes down.
    private func rebuildCards() {
        var existing = Dictionary(grouping: cards, by: { $0.issuer.id })
        var rebuilt: [TrackedCard] = []
        for pick in picks {
            for _ in 0..<pick.count {
                if var kept = existing[pick.issuerID], !kept.isEmpty {
                    rebuilt.append(kept.removeFirst())
                    existing[pick.issuerID] = kept
                } else if let issuer = resolvedIssuer(withID: pick.issuerID) {
                    rebuilt.append(TrackedCard(issuer: issuer))
                }
            }
        }
        cards = rebuilt
    }

    // MARK: Add another card (from the review screen)

    /// "Add another card": opens "Pick your cards" again with the current cards already counted.
    func startAddingCards() {
        picks = Self.issuerPicks(from: cards)
        lockedCounts = Dictionary(picks.map { ($0.issuerID, $0.count) }, uniquingKeysWith: { first, _ in first })
        addBatch = []
        path.append(.addCards)
    }

    /// The cards the user already had from this issuer when the second pick screen opened.
    func lockedCount(of issuer: Issuer) -> Int {
        lockedCounts[issuer.id] ?? 0
    }

    /// How many new cards are picked on the second pick screen.
    var newPickCount: Int {
        picks.reduce(0) { $0 + max(0, $1.count - (lockedCounts[$1.issuerID] ?? 0)) }
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
        if let reviewIndex = path.lastIndex(of: .review) {
            path = Array(path.prefix(through: reviewIndex))
        } else {
            path.append(.review)
        }
    }

    /// The issuers of `cards` in order, each with how many cards it has.
    private static func issuerPicks(from cards: [TrackedCard]) -> [IssuerPick] {
        var result: [IssuerPick] = []
        for card in cards {
            if let index = result.firstIndex(where: { $0.issuerID == card.issuer.id }) {
                result[index].count += 1
            } else {
                result.append(IssuerPick(issuerID: card.issuer.id, count: 1))
            }
        }
        return result
    }

    private func resolvedIssuer(withID id: String) -> Issuer? {
        if let issuer = catalog.issuer(withID: id) ?? BuiltInIssuers.issuer(withID: id) { return issuer }
        return id.hasPrefix(Issuer.customIDPrefix) ? Issuer.custom(id: id) : nil
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

    /// Sets the name of a not-listed bank as the user types it. Listed issuers keep their names.
    func setCustomName(_ name: String, for id: UUID) {
        guard let index = cards.firstIndex(where: { $0.id == id }), cards[index].issuer.isCustom else { return }
        cards[index].issuer = Issuer.custom(id: cards[index].issuer.id, name: name)
    }

    /// What to call a card on screen: its issuer's name, with a number when the user has several cards
    /// from that issuer ("Chase 1", "Chase 2").
    func title(of card: TrackedCard) -> String {
        let name = card.issuer.displayName
        let sameIssuer = cards.filter { $0.issuer.id == card.issuer.id }
        guard sameIssuer.count > 1, let index = sameIssuer.firstIndex(where: { $0.id == card.id }) else {
            return name
        }
        return "\(name) \(index + 1)"
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
        removeOnePick(forIssuerID: removed.issuer.id)

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

    /// One card fewer from this issuer; the issuer is unticked when that was its last card.
    private func removeOnePick(forIssuerID issuerID: String) {
        guard let index = picks.firstIndex(where: { $0.issuerID == issuerID }) else { return }
        if picks[index].count > 1 {
            picks[index].count -= 1
        } else {
            picks.remove(at: index)
        }
    }

    // MARK: Review

    func finishOnboarding() {
        // TODO(supabase): save the cards to the user's account.
        hasFinishedOnboarding = true
        path = []
    }
}
