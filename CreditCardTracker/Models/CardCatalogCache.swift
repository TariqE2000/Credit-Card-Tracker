import Foundation

/// The card list as saved on the phone.
struct CachedCatalog: Codable, Equatable {
    /// The opencard-db release tag the cards came from, such as "v0.4.2".
    var source: String
    var cards: [CatalogCard]
}

/// Keeps the downloaded list on the phone so later launches need no download.
protocol CardCatalogCaching {
    func load() -> CachedCatalog?
    func save(_ catalog: CachedCatalog)
}

/// Saves the list as one small JSON file in the app's Application Support folder. It is left out of
/// iCloud backups because it can always be downloaded again.
struct FileCardCatalogCache: CardCatalogCaching {
    let fileURL: URL

    init(fileURL: URL = FileCardCatalogCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("CardCatalog", isDirectory: true)
            // "-v2": cards in the first version of this file have no issuer ID, which the bundled logos
            // need. A new name makes the app download the list once more and save it with IDs.
            .appendingPathComponent("us-cards-v2.json")
    }

    func load() -> CachedCatalog? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CachedCatalog.self, from: data)
    }

    /// Saving is best effort. If it fails, the next launch simply downloads the list again.
    func save(_ catalog: CachedCatalog) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(catalog).write(to: fileURL, options: .atomic)

            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var url = fileURL
            try? url.setResourceValues(values)
        } catch {
            // Nothing to do: see above.
        }
    }
}
