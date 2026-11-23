import Foundation

/// A short built-in list of popular issuers. It is only used while the full list cannot be loaded (the
/// first launch with no internet), and in previews and tests. The full list comes from
/// `IssuerCatalogStore`.
///
/// Each ID is the issuer's ID in opencard-db, so an issuer picked from this list is still recognized as
/// the same issuer once the full list has loaded. Badge letters, colors and logos come from `IssuerStyle`.
enum BuiltInIssuers {
    static let all: [Issuer] = [
        Issuer(id: "chase", name: "Chase"),
        Issuer(id: "amex", name: "American Express"),
        Issuer(id: "capital-one", name: "Capital One"),
        Issuer(id: "citi", name: "Citi"),
        Issuer(id: "discover", name: "Discover"),
        Issuer(id: "wells-fargo", name: "Wells Fargo"),
        Issuer(id: "bank-of-america", name: "Bank of America"),
        Issuer(id: "us-bank", name: "U.S. Bank"),
        Issuer(id: "barclays", name: "Barclays"),
        Issuer(id: "synchrony", name: "Synchrony Bank"),
        Issuer(id: "navy-federal", name: "Navy Federal Credit Union"),
        Issuer(id: "usaa", name: "USAA Federal Savings Bank"),
    ]

    static func issuer(withID id: String) -> Issuer? {
        all.first { $0.id == id }
    }

    /// Issuers in the built-in list whose name contains `query`.
    static func issuers(matching query: String) -> [Issuer] {
        all.filter { $0.matches(query) }
    }
}
