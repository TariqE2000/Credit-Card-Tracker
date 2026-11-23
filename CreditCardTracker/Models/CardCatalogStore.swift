import Combine
import Foundation

/// The cards the user can pick from, and the work of getting them.
///
/// How it behaves:
/// 1. If a list is already saved on the phone, it is shown right away. When it came from the release
///    the app is pinned to (`CardCatalogSource.tag`), no download happens at all.
/// 2. Otherwise the list is downloaded from the CDN, filtered to US cards, saved on the phone and shown.
/// 3. If the download fails and nothing is saved, the built-in starter cards are shown with a "try
///    again" option, so the user can still pick a card (or use "My card is not listed").
@MainActor
final class CardCatalogStore: ObservableObject {
    enum Phase: Equatable {
        /// Waiting for the first download. There is nothing to show yet.
        case loading
        /// The full list is showing.
        case ready
        /// The download failed and nothing was saved, so the built-in starter cards are showing.
        case unavailable
    }

    @Published private(set) var cards: [CatalogCard]
    @Published private(set) var phase: Phase

    private let tag: String
    private let cache: (any CardCatalogCaching)?
    private let fetcher: (any CardCatalogFetching)?
    private let builtInCards: [CatalogCard]

    /// The release tag of the list that is showing. Nil while showing the built-in cards.
    private var shownSource: String?
    private var index: [String: CatalogCard] = [:]
    private var loadTask: Task<Void, Never>?

    /// Without a `fetcher` this store never downloads and just shows `builtInCards`.
    init(
        tag: String = CardCatalogSource.tag,
        cache: (any CardCatalogCaching)?,
        fetcher: (any CardCatalogFetching)?,
        builtInCards: [CatalogCard] = CardCatalog.all
    ) {
        self.tag = tag
        self.cache = cache
        self.fetcher = fetcher
        self.builtInCards = builtInCards

        if let saved = cache?.load(), !saved.cards.isEmpty {
            cards = saved.cards
            phase = .ready
            shownSource = saved.source
        } else if fetcher == nil {
            cards = builtInCards
            phase = .ready
        } else {
            cards = []
            phase = .loading
        }
        rebuildIndex()
    }

    /// The store the app uses: saves to the phone and downloads from the CDN.
    static func live() -> CardCatalogStore {
        CardCatalogStore(cache: FileCardCatalogCache(), fetcher: URLSessionCardFetcher())
    }

    /// The built-in starter cards only, with no downloads and nothing saved. For previews and tests.
    static func builtIn() -> CardCatalogStore {
        CardCatalogStore(cache: nil, fetcher: nil)
    }

    // MARK: Looking cards up

    func card(withID id: String) -> CatalogCard? {
        index[id]
    }

    /// Cards whose name or issuer contains `query`. An empty query returns the whole list.
    func cards(matching query: String) -> [CatalogCard] {
        CardCatalog.search(cards, matching: query)
    }

    // MARK: Loading

    /// Downloads the list if the one on screen is not from the pinned release. Safe to call more than once.
    func load() async {
        if let loadTask {
            await loadTask.value
            return
        }
        guard fetcher != nil, shownSource != tag else { return }

        let task = Task { await self.download() }
        loadTask = task
        await task.value
        loadTask = nil
    }

    /// "Try again" after a failed download.
    func retry() async {
        await load()
    }

    private func download() async {
        guard let fetcher else { return }
        do {
            let data = try await fetcher.data(from: CardCatalogSource.url(forTag: tag))
            // Reading 2 MB of JSON takes a moment, so it is done away from the main thread.
            let fresh = try await Task.detached(priority: .userInitiated) {
                try OpenCardMapper.catalogCards(from: data)
            }.value

            cards = fresh
            rebuildIndex()
            phase = .ready
            shownSource = tag
            cache?.save(CachedCatalog(source: tag, cards: fresh))
        } catch {
            // A list saved earlier (from an older release) stays on screen. With nothing saved,
            // fall back to the built-in starter cards.
            if cards.isEmpty {
                cards = builtInCards
                rebuildIndex()
                phase = .unavailable
            }
        }
    }

    private func rebuildIndex() {
        index = Dictionary(cards.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
