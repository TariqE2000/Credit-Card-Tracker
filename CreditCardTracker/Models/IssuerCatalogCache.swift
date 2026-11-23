import Foundation

/// The issuer list as saved on the phone.
struct CachedIssuers: Codable, Equatable {
    /// The opencard-db release tag the issuers came from, such as "v0.4.2".
    var source: String
    var issuers: [Issuer]
}

/// Keeps the downloaded list on the phone so later launches need no download.
protocol IssuerCatalogCaching {
    func load() -> CachedIssuers?
    func save(_ catalog: CachedIssuers)
}

/// Saves the list as one small JSON file in the app's Application Support folder. It is left out of
/// iCloud backups because it can always be downloaded again.
struct FileIssuerCatalogCache: IssuerCatalogCaching {
    let fileURL: URL

    init(fileURL: URL = FileIssuerCatalogCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("BuiltInIssuers", isDirectory: true)
            .appendingPathComponent("us-issuers.json")
    }

    func load() -> CachedIssuers? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(CachedIssuers.self, from: data)
    }

    /// Saving is best effort. If it fails, the next launch simply downloads the list again.
    func save(_ catalog: CachedIssuers) {
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
