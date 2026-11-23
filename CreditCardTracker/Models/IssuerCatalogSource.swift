import Foundation

/// Where the full card list comes from.
///
/// The list is opencard-db, an open-source database of credit cards (code MIT, data CC BY 4.0). Its
/// JSON files are served by the jsDelivr CDN, which needs no account, no key and has no request limit.
///
/// We pin one release tag. A tagged address never changes, so a mistake in their newest data cannot
/// break the app. New cards reach the app when we change `tag` and ship an update.
enum IssuerCatalogSource {
    /// The opencard-db release the app reads.
    ///
    /// To update the list: pick a newer tag from https://github.com/thedavidweng/opencard-db/releases,
    /// change this line, and check that the Pick cards screen still loads.
    static let tag = "v0.4.2"

    /// Shown in the app as the credit the CC BY 4.0 license asks for.
    static let repositoryURL = URL(string: "https://github.com/thedavidweng/opencard-db")!

    /// The file that holds every card (US, Canada and China). We keep only the US cards.
    static func url(forTag tag: String = IssuerCatalogSource.tag) -> URL {
        URL(string: "https://cdn.jsdelivr.net/gh/thedavidweng/opencard-db@\(tag)/exports/cards-all.json")!
    }
}
