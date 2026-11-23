import Combine
import Foundation

/// The issuers the user can pick from, and the work of getting them.
///
/// How it behaves:
/// 1. If a list is already saved on the phone, it is shown right away. When it came from the release
///    the app is pinned to (`IssuerCatalogSource.tag`), no download happens at all.
/// 2. Otherwise the list is downloaded from the CDN, filtered to issuers with US cards, saved on the
///    phone and shown.
/// 3. If the download fails and nothing is saved, the built-in starter issuers are shown with a "try
///    again" option, so the user can still pick an issuer (or use "My bank is not listed").
@MainActor
final class IssuerCatalogStore: ObservableObject {
    enum Phase: Equatable {
        /// Waiting for the first download. There is nothing to show yet.
        case loading
        /// The full list is showing.
        case ready
        /// The download failed and nothing was saved, so the built-in starter issuers are showing.
        case unavailable
    }

    @Published private(set) var issuers: [Issuer]
    @Published private(set) var phase: Phase

    private let tag: String
    private let cache: (any IssuerCatalogCaching)?
    private let fetcher: (any IssuerCatalogFetching)?
    private let builtInIssuers: [Issuer]

    /// The release tag of the list that is showing. Nil while showing the built-in issuers.
    private var shownSource: String?
    private var index: [String: Issuer] = [:]
    private var loadTask: Task<Void, Never>?

    /// Without a `fetcher` this store never downloads and just shows `builtInIssuers`.
    init(
        tag: String = IssuerCatalogSource.tag,
        cache: (any IssuerCatalogCaching)?,
        fetcher: (any IssuerCatalogFetching)?,
        builtInIssuers: [Issuer] = BuiltInIssuers.all
    ) {
        self.tag = tag
        self.cache = cache
        self.fetcher = fetcher
        self.builtInIssuers = builtInIssuers

        if let saved = cache?.load(), !saved.issuers.isEmpty {
            issuers = saved.issuers
            phase = .ready
            shownSource = saved.source
        } else if fetcher == nil {
            issuers = builtInIssuers
            phase = .ready
        } else {
            issuers = []
            phase = .loading
        }
        rebuildIndex()
    }

    /// The store the app uses: saves to the phone and downloads from the CDN.
    static func live() -> IssuerCatalogStore {
        IssuerCatalogStore(cache: FileIssuerCatalogCache(), fetcher: URLSessionCatalogFetcher())
    }

    /// The built-in starter issuers only, with no downloads and nothing saved. For previews and tests.
    static func builtIn() -> IssuerCatalogStore {
        IssuerCatalogStore(cache: nil, fetcher: nil)
    }

    // MARK: Looking issuers up

    func issuer(withID id: String) -> Issuer? {
        index[id]
    }

    /// Issuers whose name contains `query`. An empty query returns the whole list.
    func issuers(matching query: String) -> [Issuer] {
        issuers.filter { $0.matches(query) }
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
            // The two files are small (about 15 KB and 22 KB) and are asked for at the same time.
            let registryURL = IssuerCatalogSource.registryURL(forTag: tag)
            let indexURL = IssuerCatalogSource.indexURL(forTag: tag)
            async let registryData = fetcher.data(from: registryURL)
            async let indexData = fetcher.data(from: indexURL)
            let fresh = try OpenCardMapper.issuers(registryData: await registryData, indexData: await indexData)

            issuers = fresh
            rebuildIndex()
            phase = .ready
            shownSource = tag
            cache?.save(CachedIssuers(source: tag, issuers: fresh))
        } catch {
            // A list saved earlier (from an older release) stays on screen. With nothing saved,
            // fall back to the built-in starter issuers.
            if issuers.isEmpty {
                issuers = builtInIssuers
                rebuildIndex()
                phase = .unavailable
            }
        }
    }

    private func rebuildIndex() {
        index = Dictionary(issuers.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
