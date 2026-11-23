import XCTest
@testable import CreditCardTracker

// MARK: - Helpers

/// One entry of opencard-db's `data/issuers.json`, with extra fields on purpose (the mapper must ignore
/// everything it does not use).
private func registryEntry(_ id: String, _ name: String) -> [String: Any] {
    ["id": id, "name": name, "aliases": [id], "domains": ["example.com"]]
}

private func registryData(_ entries: [Any]) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["$comment": "test file", "issuers": entries])
}

/// `exports/index-issuer.json`: each issuer ID with the IDs of its cards.
private func indexData(_ cardIDsByIssuer: [String: [String]]) throws -> Data {
    try JSONSerialization.data(withJSONObject: cardIDsByIssuer)
}

/// Both files for issuers that all have a US card.
private func files(for issuers: [(id: String, name: String)]) throws -> (registry: Data, index: Data) {
    let registry = try registryData(issuers.map { registryEntry($0.id, $0.name) })
    let index = try indexData(Dictionary(uniqueKeysWithValues: issuers.map { ($0.id, ["us-\($0.id)-card"]) }))
    return (registry, index)
}

/// Both files with `count` US issuers, enough to pass the mapper's "this is the real list" check.
private func bigFiles(count: Int = 25, plus extra: [(id: String, name: String)] = []) throws -> (registry: Data, index: Data) {
    let fillers = (0..<count).map { (id: "bank-\($0)", name: "Bank \($0)") }
    return try files(for: fillers + extra)
}

private let sampleIssuer = Issuer(
    id: "sample",
    name: "Sample Bank",
    badgeCode: "SB",
    badgeColorHex: 0x123456,
    logoDomain: "example.com"
)

// MARK: - Mapper

final class OpenCardMapperTests: XCTestCase {
    func testKeepsOnlyIssuersWithAUSCard() throws {
        let registry = try registryData([
            registryEntry("chase", "Chase"),
            registryEntry("mbna", "MBNA"),
            registryEntry("icbc", "ICBC"),
        ])
        let index = try indexData([
            "chase": ["us-chase-a"],
            "mbna": ["ca-mbna-b"],
            "icbc": ["cn-icbc-c", "us-icbc-d"],
        ])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        XCTAssertEqual(issuers.map(\.id), ["chase", "icbc"])
    }

    func testAnIssuerWithNoCardsIsLeftOut() throws {
        let registry = try registryData([registryEntry("chase", "Chase"), registryEntry("ghost", "Ghost Bank")])
        let index = try indexData(["chase": ["us-chase-a"]])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        XCTAssertEqual(issuers.map(\.id), ["chase"])
    }

    func testSkipsBrokenAndDuplicateEntriesWithoutFailing() throws {
        let registry = try registryData([
            registryEntry("good", "Good Bank"),
            ["id": "no-name"],
            "not even an object",
            registryEntry("blank", "   "),
            registryEntry("good", "Good Bank again"),
        ])
        let index = try indexData(["good": ["us-good-a"], "no-name": ["us-x"], "blank": ["us-y"]])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        XCTAssertEqual(issuers.map(\.id), ["good"])
        XCTAssertEqual(issuers.first?.name, "Good Bank")
    }

    func testRefusesAListThatIsTooSmallToBeTheRealOne() throws {
        let (registry, index) = try files(for: [(id: "chase", name: "Chase")])
        XCTAssertThrowsError(try OpenCardMapper.issuers(registryData: registry, indexData: index)) { error in
            XCTAssertEqual(error as? IssuerCatalogError, .notEnoughIssuers(1))
        }
    }

    func testRefusesSomethingThatIsNotJSON() throws {
        let page = Data("<html>Not found</html>".utf8)
        let (registry, index) = try bigFiles()
        XCTAssertThrowsError(try OpenCardMapper.issuers(registryData: page, indexData: index))
        XCTAssertThrowsError(try OpenCardMapper.issuers(registryData: registry, indexData: page))
    }

    func testBigIssuersComeFirstThenTheRestAlphabetically() throws {
        let (registry, index) = try files(for: [
            (id: "zeta", name: "Zeta Bank"),
            (id: "citi", name: "Citi"),
            (id: "alpha", name: "Alpha Credit Union"),
            (id: "amex", name: "American Express"),
            (id: "chase", name: "Chase"),
        ])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        XCTAssertEqual(issuers.map(\.id), ["chase", "amex", "citi", "alpha", "zeta"])
    }

    func testBigIssuersKeepTheirColorsAndLogos() throws {
        let (registry, index) = try files(for: [
            (id: "chase", name: "Chase"),
            (id: "amex", name: "American Express"),
        ])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        let chase = try XCTUnwrap(issuers.first { $0.id == "chase" })
        let amex = try XCTUnwrap(issuers.first { $0.id == "amex" })

        XCTAssertEqual(chase.badgeCode, "CH")
        XCTAssertEqual(chase.badgeColorHex, 0x1F5BC4)
        XCTAssertNil(chase.logoDomain, "LogoAPI.sh does not have Chase")
        XCTAssertEqual(amex.badgeCode, "AX")
        XCTAssertEqual(amex.logoDomain, "americanexpress.com")
    }

    func testNamesThatWouldConfuseAUSCustomerAreReplaced() throws {
        let (registry, index) = try files(for: [
            (id: "td", name: "TD Canada Trust"),
            (id: "icbc", name: "Industrial and Commercial Bank of China 中国工商银行"),
            (id: "goldman-sachs", name: "Goldman Sachs"),
        ])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        let names = Dictionary(uniqueKeysWithValues: issuers.map { ($0.id, $0.name) })
        XCTAssertEqual(names["td"], "TD Bank")
        XCTAssertEqual(names["icbc"], "ICBC")
        XCTAssertEqual(names["goldman-sachs"], "Goldman Sachs (Apple Card)")
    }

    func testUnknownIssuerGetsLettersAndAColorFromThePalette() throws {
        let (registry, index) = try files(for: [
            (id: "navy-federal", name: "Navy Federal Credit Union"),
            (id: "mystery", name: "Mystery Bank"),
        ])
        let issuers = try OpenCardMapper.issuers(registryData: registry, indexData: index, minimumCount: 1)
        let navy = try XCTUnwrap(issuers.first { $0.id == "navy-federal" })
        let mystery = try XCTUnwrap(issuers.first { $0.id == "mystery" })

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

    func testOnlyTheNamesThatNeedItAreReplaced() {
        XCTAssertEqual(IssuerStyle.displayName(forIssuerID: "td", registryName: "TD Canada Trust"), "TD Bank")
        XCTAssertEqual(IssuerStyle.displayName(forIssuerID: "chase", registryName: "Chase"), "Chase")
    }
}

// MARK: - Search

final class IssuerSearchTests: XCTestCase {
    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(BuiltInIssuers.all.allSatisfy { $0.matches("") })
        XCTAssertTrue(BuiltInIssuers.all.allSatisfy { $0.matches("   ") })
    }

    func testMatchesPartOfTheNameIgnoringCase() {
        XCTAssertEqual(BuiltInIssuers.issuers(matching: "american").map(\.id), ["amex"])
        XCTAssertEqual(BuiltInIssuers.issuers(matching: "NAVY fed").map(\.id), ["navy-federal"])
    }

    func testMatchesTheIssuerIDSoAmexFindsAmericanExpress() {
        XCTAssertEqual(BuiltInIssuers.issuers(matching: "amex").map(\.id), ["amex"])
        XCTAssertEqual(BuiltInIssuers.issuers(matching: "us bank").map(\.id), ["us-bank"])
    }

    func testNothingMatchesGibberish() {
        XCTAssertTrue(BuiltInIssuers.issuers(matching: "zzzz").isEmpty)
    }
}

// MARK: - Saved copy on the phone

final class IssuerCatalogCacheTests: XCTestCase {
    private func temporaryCache() -> FileIssuerCatalogCache {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return FileIssuerCatalogCache(fileURL: folder.appendingPathComponent("us-issuers.json"))
    }

    func testNothingSavedYet() {
        XCTAssertNil(temporaryCache().load())
    }

    func testSavedListComesBackTheSame() {
        let cache = temporaryCache()
        cache.save(CachedIssuers(source: "v1", issuers: [sampleIssuer]))
        XCTAssertEqual(cache.load(), CachedIssuers(source: "v1", issuers: [sampleIssuer]))
    }

    func testASecondSaveReplacesTheFirst() {
        let cache = temporaryCache()
        cache.save(CachedIssuers(source: "v1", issuers: [sampleIssuer]))
        cache.save(CachedIssuers(source: "v2", issuers: []))
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

    func testTheSavedFileHasADifferentNameThanTheOldCardList() {
        XCTAssertEqual(FileIssuerCatalogCache.defaultFileURL.lastPathComponent, "us-issuers.json")
    }
}

// MARK: - Store

/// Answers with whatever it is told to, and remembers what was asked for. The store asks for two files
/// at the same time, so the list of requests is guarded by a lock.
private final class StubFetcher: IssuerCatalogFetching, @unchecked Sendable {
    var result: Result<(registry: Data, index: Data), Error>
    private let lock = NSLock()
    private var urls: [URL] = []

    init(_ result: Result<(registry: Data, index: Data), Error>) {
        self.result = result
    }

    var requestedURLs: Set<URL> {
        lock.lock()
        defer { lock.unlock() }
        return Set(urls)
    }

    func data(from url: URL) async throws -> Data {
        lock.lock()
        urls.append(url)
        lock.unlock()

        let files = try result.get()
        return url.path.hasSuffix("data/issuers.json") ? files.registry : files.index
    }
}

private final class MemoryCache: IssuerCatalogCaching {
    var saved: CachedIssuers?
    init(_ saved: CachedIssuers? = nil) { self.saved = saved }
    func load() -> CachedIssuers? { saved }
    func save(_ catalog: CachedIssuers) { saved = catalog }
}

@MainActor
final class IssuerCatalogStoreTests: XCTestCase {
    private struct Offline: Error {}

    func testFirstLaunchDownloadsFiltersAndSavesTheList() async throws {
        let cache = MemoryCache()
        let fetcher = StubFetcher(.success(try bigFiles()))
        let store = IssuerCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)
        XCTAssertEqual(store.phase, .loading)
        XCTAssertTrue(store.issuers.isEmpty)

        await store.load()

        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.issuers.count, 25)
        XCTAssertEqual(
            fetcher.requestedURLs,
            [IssuerCatalogSource.registryURL(forTag: "v9.9.9"), IssuerCatalogSource.indexURL(forTag: "v9.9.9")]
        )
        XCTAssertEqual(cache.saved?.source, "v9.9.9")
        XCTAssertEqual(cache.saved?.issuers.count, 25)
    }

    func testTheTwoFilesAreSmallOnesFromThePinnedRelease() {
        XCTAssertEqual(
            IssuerCatalogSource.registryURL(forTag: "v0.4.2").absoluteString,
            "https://cdn.jsdelivr.net/gh/thedavidweng/opencard-db@v0.4.2/data/issuers.json"
        )
        XCTAssertEqual(
            IssuerCatalogSource.indexURL(forTag: "v0.4.2").absoluteString,
            "https://cdn.jsdelivr.net/gh/thedavidweng/opencard-db@v0.4.2/exports/index-issuer.json"
        )
    }

    func testAListSavedFromThePinnedReleaseIsUsedWithoutDownloading() async throws {
        let cache = MemoryCache(CachedIssuers(source: "v9.9.9", issuers: [sampleIssuer]))
        let fetcher = StubFetcher(.success(try bigFiles()))
        let store = IssuerCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)

        XCTAssertEqual(store.phase, .ready, "shown at once, before anything loads")
        XCTAssertEqual(store.issuers, [sampleIssuer])

        await store.load()

        XCTAssertTrue(fetcher.requestedURLs.isEmpty)
        XCTAssertEqual(store.issuers, [sampleIssuer])
    }

    func testAListFromAnOlderReleaseIsShownThenReplaced() async throws {
        let cache = MemoryCache(CachedIssuers(source: "v1", issuers: [sampleIssuer]))
        let fetcher = StubFetcher(.success(try bigFiles()))
        let store = IssuerCatalogStore(tag: "v2", cache: cache, fetcher: fetcher)
        XCTAssertEqual(store.issuers, [sampleIssuer])

        await store.load()

        XCTAssertEqual(store.issuers.count, 25)
        XCTAssertEqual(cache.saved?.source, "v2")
    }

    func testFailedFirstDownloadShowsTheBuiltInIssuersAndRetryRecovers() async throws {
        let cache = MemoryCache()
        let fetcher = StubFetcher(.failure(Offline()))
        let store = IssuerCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)

        await store.load()
        XCTAssertEqual(store.phase, .unavailable)
        XCTAssertEqual(store.issuers, BuiltInIssuers.all)
        XCTAssertNil(cache.saved, "nothing is saved after a failure")

        fetcher.result = .success(try bigFiles())
        await store.retry()

        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.issuers.count, 25)
        XCTAssertEqual(cache.saved?.source, "v9.9.9")
    }

    func testFailedDownloadKeepsAnOlderSavedList() async throws {
        let cache = MemoryCache(CachedIssuers(source: "v1", issuers: [sampleIssuer]))
        let fetcher = StubFetcher(.failure(Offline()))
        let store = IssuerCatalogStore(tag: "v2", cache: cache, fetcher: fetcher)

        await store.load()

        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.issuers, [sampleIssuer])
        XCTAssertEqual(cache.saved?.source, "v1", "the older copy is left alone")
    }

    func testADownloadThatIsNotTheRealListIsNotUsedOrSaved() async throws {
        let cache = MemoryCache()
        let tinyFiles = try files(for: [(id: "chase", name: "Chase")])
        let store = IssuerCatalogStore(tag: "v9.9.9", cache: cache, fetcher: StubFetcher(.success(tinyFiles)))

        await store.load()

        XCTAssertEqual(store.phase, .unavailable)
        XCTAssertEqual(store.issuers, BuiltInIssuers.all)
        XCTAssertNil(cache.saved)
    }

    func testBuiltInStoreNeverDownloads() async {
        let store = IssuerCatalogStore.builtIn()
        XCTAssertEqual(store.phase, .ready)
        XCTAssertEqual(store.issuers, BuiltInIssuers.all)
        await store.load()
        XCTAssertEqual(store.issuers, BuiltInIssuers.all)
    }

    func testLookupAndSearchUseTheLoadedList() async throws {
        let data = try bigFiles(plus: [(id: "chase", name: "Chase"), (id: "citi", name: "Citi")])
        let store = IssuerCatalogStore(tag: "v9.9.9", cache: MemoryCache(), fetcher: StubFetcher(.success(data)))
        await store.load()

        XCTAssertEqual(store.issuer(withID: "citi")?.name, "Citi")
        XCTAssertNil(store.issuer(withID: "nope"))
        XCTAssertEqual(store.issuers(matching: "citi").map(\.id), ["citi"])
        XCTAssertEqual(store.issuers(matching: "").count, store.issuers.count)
        XCTAssertEqual(store.issuers.prefix(2).map(\.id), ["chase", "citi"], "big issuers come first")
    }

    func testAnIssuerPickedFromTheBuiltInListSurvivesTheFullListLoading() async throws {
        // Pick a built-in issuer while offline, then let the full list arrive: the same issuer must
        // still resolve.
        let cache = MemoryCache()
        let fetcher = StubFetcher(.failure(Offline()))
        let catalog = IssuerCatalogStore(tag: "v9.9.9", cache: cache, fetcher: fetcher)
        let store = OnboardingStore(catalog: catalog)
        await catalog.load()

        let amex = try XCTUnwrap(catalog.issuer(withID: "amex"))
        store.toggleSelection(of: amex)

        fetcher.result = .success(try bigFiles(plus: [(id: "amex", name: "American Express")]))
        await catalog.retry()

        store.continueFromPickCards()
        XCTAssertEqual(store.cards.map(\.issuer.id), ["amex"])
        XCTAssertEqual(store.cards.first?.issuer.name, "American Express")
    }
}
