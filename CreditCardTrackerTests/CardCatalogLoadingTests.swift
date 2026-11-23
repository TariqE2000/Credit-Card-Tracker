import XCTest
@testable import CreditCardTracker

// MARK: - Helpers

/// A card record shaped like one entry of opencard-db's `cards-all.json`, with extra fields on purpose
/// (the mapper must ignore everything it does not use).
private func cardRecord(
    _ id: String,
    _ name: String,
    issuer: String = "Chase",
    issuerID: String = "chase",
    country: String = "us"
) -> [String: Any] {
    [
        "id": id,
        "name": name,
        "country": country,
        "issuer": issuer,
        "issuer_id": issuerID,
        "status": "active",
        "segment": "personal",
        "rewards": ["currency": "points"],
        "benefits": ["lounge_access", "trip_insurance"],
    ]
}

private func jsonData(_ items: [Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: items)
}

/// A file with enough US cards to pass the mapper's "this is the real list" check.
private func bigFile(count: Int = 60) throws -> Data {
    try jsonData((0..<count).map { cardRecord("us-card-\($0)", "Card \($0)") })
}

private let sampleCard = CatalogCard(
    id: "us-sample",
    name: "Sample Card",
    issuer: "Sample Bank",
    badgeCode: "SB",
    badgeColorHex: 0x123456,
    logoDomain: "example.com"
)

// MARK: - Mapper

final class OpenCardMapperTests: XCTestCase {
    func testKeepsOnlyUSCards() throws {
        let data = try jsonData([
            cardRecord("us-a", "Card A"),
            cardRecord("ca-b", "Card B", issuer: "MBNA", issuerID: "mbna", country: "ca"),
            cardRecord("cn-c", "Card C", issuer: "ICBC", issuerID: "icbc", country: "cn"),
        ])
        let cards = try OpenCardMapper.catalogCards(from: data, minimumCount: 1)
        XCTAssertEqual(cards.map(\.id), ["us-a"])
    }

    func testSkipsBrokenAndDuplicateEntriesWithoutFailing() throws {
        let data = try jsonData([
            cardRecord("us-good", "Good Card"),
            ["id": "us-no-name", "country": "us", "issuer": "Chase", "issuer_id": "chase"],
            "not even an object",
            cardRecord("us-blank", "   "),
            cardRecord("us-good", "Good Card again"),
        ])
        let cards = try OpenCardMapper.catalogCards(from: data, minimumCount: 1)
        XCTAssertEqual(cards.map(\.id), ["us-good"])
        XCTAssertEqual(cards.first?.name, "Good Card")
    }

    func testRefusesAListThatIsTooSmallToBeTheRealOne() throws {
        let data = try jsonData([cardRecord("us-a", "Card A")])
        XCTAssertThrowsError(try OpenCardMapper.catalogCards(from: data)) { error in
            XCTAssertEqual(error as? CardCatalogError, .notEnoughCards(1))
        }
    }

    func testRefusesSomethingThatIsNotAList() {
        let page = Data("<html>Not found</html>".utf8)
        XCTAssertThrowsError(try OpenCardMapper.catalogCards(from: page))
    }

    func testBigIssuersComeFirstThenTheRestAlphabetically() throws {
        let data = try jsonData([
            cardRecord("us-z", "Zeta Card", issuer: "Zeta Bank", issuerID: "zeta"),
            cardRecord("us-citi", "Citi Custom Cash", issuer: "Citi", issuerID: "citi"),
            cardRecord("us-a2", "Alpha Two", issuer: "Alpha Credit Union", issuerID: "alpha"),
            cardRecord("us-amex", "Gold", issuer: "American Express", issuerID: "amex"),
            cardRecord("us-chase-b", "Chase Sapphire", issuer: "Chase", issuerID: "chase"),
            cardRecord("us-chase-a", "Chase Freedom", issuer: "Chase", issuerID: "chase"),
            cardRecord("us-a1", "Alpha One", issuer: "Alpha Credit Union", issuerID: "alpha"),
        ])
        let cards = try OpenCardMapper.catalogCards(from: data, minimumCount: 1)
        XCTAssertEqual(
            cards.map(\.id),
            ["us-chase-a", "us-chase-b", "us-amex", "us-citi", "us-a1", "us-a2", "us-z"]
        )
    }

    func testBigIssuersKeepTheirColorsAndLogos() throws {
        let data = try jsonData([
            cardRecord("us-chase-x", "Chase X", issuer: "Chase", issuerID: "chase"),
            cardRecord("us-amex-x", "Amex X", issuer: "American Express", issuerID: "amex"),
        ])
        let cards = try OpenCardMapper.catalogCards(from: data, minimumCount: 1)
        let chase = try XCTUnwrap(cards.first { $0.id == "us-chase-x" })
        let amex = try XCTUnwrap(cards.first { $0.id == "us-amex-x" })

        XCTAssertEqual(chase.badgeCode, "CH")
        XCTAssertEqual(chase.badgeColorHex, 0x1F5BC4)
        XCTAssertNil(chase.logoDomain, "LogoAPI.sh does not have Chase")
        XCTAssertEqual(amex.badgeCode, "AX")
        XCTAssertEqual(amex.logoDomain, "americanexpress.com")
    }

    func testAppleCardIsStyledAsAppleEvenThoughGoldmanSachsIssuesIt() throws {
        let data = try jsonData([
            cardRecord("us-apple-card", "Apple Card", issuer: "Goldman Sachs", issuerID: "goldman-sachs"),
        ])
        let card = try XCTUnwrap(OpenCardMapper.catalogCards(from: data, minimumCount: 1).first)
        XCTAssertEqual(card.issuer, "Goldman Sachs")
        XCTAssertEqual(card.badgeCode, "AP")
        XCTAssertEqual(card.logoDomain, "apple.com")
    }

    func testUnknownIssuerGetsLettersAndAColorFromThePalette() throws {
        let data = try jsonData([
            cardRecord("us-n", "Navy Card", issuer: "Navy Federal Credit Union", issuerID: "navy-federal"),
            cardRecord("us-x", "Mystery Card", issuer: "Mystery Bank", issuerID: "mystery"),
        ])
        let cards = try OpenCardMapper.catalogCards(from: data, minimumCount: 1)
        let navy = try XCTUnwrap(cards.first { $0.id == "us-n" })
        let mystery = try XCTUnwrap(cards.first { $0.id == "us-x" })

        XCTAssertEqual(navy.badgeCode, "NF")
        XCTAssertEqual(navy.logoDomain, "navyfederal.org")
        XCTAssertTrue(IssuerStyle.palette.contains(mystery.badgeColorHex))
        XCTAssertNil(mystery.logoDomain)
    }
}

final class IssuerStyleTests: XCTestCase {
    func testBadgeLettersFromTheIssuerName() {
        XCTAssertEqual(IssuerStyle.fallbackCode(forIssuerName: "Navy Federal Credit Union"), "NF")
        XCTAssertEqual(IssuerStyle.fallbackCode(forIssuerName: "SoFi"), "SO")
        XCTAssertEqual(IssuerStyle.fallbackCode(forIssuerName: "First Electronic Bank"), "FE")
        XCTAssertEqual(IssuerStyle.fallbackCode(forIssuerName: "  "), "?")
    }

    func testTheRuleCannotSpellUSBankSoItHasAnOverride() {
        XCTAssertEqual(IssuerStyle.style(forIssuerID: "us-bank", issuerName: "U.S. Bank").code, "US")
    }

    func testAnIssuerAlwaysGetsTheSameColor() {
        let first = IssuerStyle.fallbackColor(forIssuerID: "navy-federal")
        XCTAssertEqual(first, IssuerStyle.fallbackColor(forIssuerID: "navy-federal"))
        XCTAssertTrue(IssuerStyle.palette.contains(first))
    }

    func testTheStableHashDoesNotChangeBetweenLaunches() {
        // Known FNV-1a (64-bit) values. If these change, every issuer's color changes with them.
        XCTAssertEqual(IssuerStyle.stableHash(""), 0xcbf2_9ce4_8422_2325)
        XCTAssertEqual(IssuerStyle.stableHash("a"), 0xaf63_dc4c_8601_ec8c)
    }
}

// MARK: - Saved copy on the phone

final class CardCatalogCacheTests: XCTestCase {
    private func temporaryCache() -> FileCardCatalogCache {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return FileCardCatalogCache(fileURL: folder.appendingPathComponent("us-cards.json"))
    }

    func testNothingSavedYet() {
        XCTAssertNil(temporaryCache().load())
    }

    func testSavedListComesBackTheSame() {
        let cache = temporaryCache()
        cache.save(CachedCatalog(source: "v1", cards: [sampleCard]))
        XCTAssertEqual(cache.load(), CachedCatalog(source: "v1", cards: [sampleCard]))
    }

    func testASecondSaveReplacesTheFirst() {
        let cache = temporaryCache()
        cache.save(CachedCatalog(source: "v1", cards: [sampleCard]))
        cache.save(CachedCatalog(source: "v2", cards: []))
        XCTAssertEqual(cache.load()?.source, "v2")
    }

    func testAFileThatIsNotOurJSONIsTreatedAsNothingSaved() throws {
        let cache = temporaryCache()
        try FileManager.default.createDirectory(
            at: cache.fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("garbage".utf8).write(to: cache.fileURL)
        XCTAssertNil(cache.load())
    }
}

// MARK: - Store

/// Answers with whatever it is told to, and remembers what was asked for.
private final class StubFetcher: CardCatalogFetching, @unchecked Sendable {
    var result: Result<Data, Error>
    private(set) var requestedURLs: [URL] = []

    init(_ result: Result<Data, Error>) {
        self.result = result
    }

    func data(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        return try result.get()
    }
}

private final class MemoryCache: CardCatalogCaching {
    var saved: CachedCatalog?
    init(_ saved: CachedCatalog? = nil) { self.saved = saved }
    func load() -> CachedCatalog? { saved }
    func save(_ catalog: CachedCatalog) { saved = catalog }
}

@MainActor
final class CardCatalogStoreTests: XCTestCase {
    private struct Offline: Error {}

    func testFirstLaunchDownloadsFiltersAndSavesTheList() async throws {
        let cache = MemoryCache()
        let fetcher = StubFetcher(.success(try bigFile()))
        let store = CardCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)
        XCTAssertEqual(store.phase, .loading)
        XCTAssertTrue(store.cards.isEmpty)

        await store.load()

        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.cards.count, 60)
        XCTAssertEqual(fetcher.requestedURLs, [CardCatalogSource.url(forTag: "v9.9.9")])
        XCTAssertEqual(cache.saved?.source, "v9.9.9")
        XCTAssertEqual(cache.saved?.cards.count, 60)
    }

    func testAListSavedFromThePinnedReleaseIsUsedWithoutDownloading() async throws {
        let cache = MemoryCache(CachedCatalog(source: "v9.9.9", cards: [sampleCard]))
        let fetcher = StubFetcher(.success(try bigFile()))
        let store = CardCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)

        XCTAssertEqual(store.phase, .ready, "shown at once, before anything loads")
        XCTAssertEqual(store.cards, [sampleCard])

        await store.load()

        XCTAssertTrue(fetcher.requestedURLs.isEmpty)
        XCTAssertEqual(store.cards, [sampleCard])
    }

    func testAListFromAnOlderReleaseIsShownThenReplaced() async throws {
        let cache = MemoryCache(CachedCatalog(source: "v1", cards: [sampleCard]))
        let fetcher = StubFetcher(.success(try bigFile()))
        let store = CardCatalogStore(tag: "v2", cache: cache, fetcher: fetcher)
        XCTAssertEqual(store.cards, [sampleCard])

        await store.load()

        XCTAssertEqual(store.cards.count, 60)
        XCTAssertEqual(cache.saved?.source, "v2")
    }

    func testFailedFirstDownloadShowsTheBuiltInCardsAndRetryRecovers() async throws {
        let cache = MemoryCache()
        let fetcher = StubFetcher(.failure(Offline()))
        let store = CardCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)

        await store.load()
        XCTAssertEqual(store.phase, .unavailable)
        XCTAssertEqual(store.cards, CardCatalog.all)
        XCTAssertNil(cache.saved, "nothing is saved after a failure")

        fetcher.result = .success(try bigFile())
        await store.retry()

        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.cards.count, 60)
        XCTAssertEqual(cache.saved?.source, "v9.9.9")
    }

    func testFailedDownloadKeepsAnOlderSavedList() async throws {
        let cache = MemoryCache(CachedCatalog(source: "v1", cards: [sampleCard]))
        let fetcher = StubFetcher(.failure(Offline()))
        let store = CardCatalogStore(tag: "v2", cache: cache, fetcher: fetcher)

        await store.load()

        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.cards, [sampleCard])
        XCTAssertEqual(cache.saved?.source, "v1", "the older copy is left alone")
    }

    func testADownloadThatIsNotTheRealListIsNotUsedOrSaved() async throws {
        let cache = MemoryCache()
        let tinyFile = try jsonData([cardRecord("us-a", "Card A")])
        let store = CardCatalogStore(tag: "v9.9.9", cache: cache, fetcher: StubFetcher(.success(tinyFile)))

        await store.load()

        XCTAssertEqual(store.phase, .unavailable)
        XCTAssertEqual(store.cards, CardCatalog.all)
        XCTAssertNil(cache.saved)
    }

    func testBuiltInStoreNeverDownloads() async {
        let store = CardCatalogStore.builtIn()
        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.cards, CardCatalog.all)
        await store.load()
        XCTAssertEqual(store.cards, CardCatalog.all)
    }

    func testLookupAndSearchUseTheLoadedList() async throws {
        let data = try jsonData([
            cardRecord("us-chase-sapphire-preferred", "Chase Sapphire Preferred® Card"),
            cardRecord("us-citi-double-cash", "Citi Double Cash® Card", issuer: "Citi", issuerID: "citi"),
        ] + (0..<60).map { cardRecord("us-filler-\($0)", "Filler \($0)", issuer: "Filler Bank", issuerID: "filler") })
        let store = CardCatalogStore(tag: "v9.9.9", cache: MemoryCache(), fetcher: StubFetcher(.success(data)))
        await store.load()

        XCTAssertEqual(store.card(withID: "us-citi-double-cash")?.issuer, "Citi")
        XCTAssertNil(store.card(withID: "nope"))
        XCTAssertEqual(store.cards(matching: "sapphire").map(\.id), ["us-chase-sapphire-preferred"])
        XCTAssertEqual(store.cards(matching: "").count, store.cards.count)
    }

    func testACardPickedFromTheBuiltInListSurvivesTheFullListLoading() async throws {
        // Pick a built-in card while offline, then let the full list arrive: the same card must still
        // resolve, and it must still be recognized as already added.
        let cache = MemoryCache()
        let fetcher = StubFetcher(.failure(Offline()))
        let catalog = CardCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)
        let store = OnboardingStore(catalog: catalog)
        await catalog.load()

        let apple = try XCTUnwrap(catalog.card(withID: "us-apple-card"))
        store.toggleSelection(of: apple)

        fetcher.result = .success(try jsonData([
            cardRecord("us-apple-card", "Apple Card", issuer: "Goldman Sachs", issuerID: "goldman-sachs"),
        ] + (0..<60).map { cardRecord("us-card-\($0)", "Card \($0)") }))
        await catalog.retry()

        store.continueFromPickCards()
        XCTAssertEqual(store.cards.map(\.catalogCard.id), ["us-apple-card"])
        XCTAssertEqual(store.cards.first?.catalogCard.issuer, "Goldman Sachs")
    }
}
