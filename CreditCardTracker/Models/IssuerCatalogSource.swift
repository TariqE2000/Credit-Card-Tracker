import Foundation

/// Where the list of issuers comes from.
///
/// The list is opencard-db, an open-source database of credit cards (code MIT, data CC BY 4.0). Its
/// JSON files are served by the jsDelivr CDN, which needs no account, no key and has no request limit.
/// We read two small files (about 37 KB together) instead of the 2.3 MB file with every card, because
/// the app only needs the issuers.
///
/// We pin one release tag. A tagged address never changes, so a mistake in their newest data cannot
/// break the app. New issuers reach the app when we change `tag` and ship an update.
enum IssuerCatalogSource {
    /// The opencard-db release the app reads.
    ///
    /// To update the list: pick a newer tag from https://github.com/thedavidweng/opencard-db/releases,
    /// change this line, and check that the Pick cards screen still loads.
    static let tag = "v0.4.2"

    /// Shown in the app as the credit the CC BY 4.0 license asks for.
    static let repositoryURL = URL(string: "https://github.com/thedavidweng/opencard-db")!

    /// The registry of every issuer (US, Canada and China): `id` and `name` for each.
    static func registryURL(forTag tag: String = IssuerCatalogSource.tag) -> URL {
        file("data/issuers.json", tag: tag)
    }

    /// Issuer ID to the IDs of its cards. A card ID starts with its country ("us-chase-freedom"), which
    /// is how the app tells which issuers have US cards.
    static func indexURL(forTag tag: String = IssuerCatalogSource.tag) -> URL {
        file("exports/index-issuer.json", tag: tag)
    }

    private static func file(_ path: String, tag: String) -> URL {
        URL(string: "https://cdn.jsdelivr.net/gh/thedavidweng/opencard-db@\(tag)/\(path)")!
    }
}
