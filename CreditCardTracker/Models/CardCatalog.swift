import Foundation

/// A short built-in list of popular cards. It is only used while the full list cannot be loaded (the
/// first launch with no internet), and in previews and tests. The full list comes from
/// `CardCatalogStore`.
///
/// Each ID is the card's ID in opencard-db, so a card picked from this list is still recognized as
/// the same card once the full list has loaded.
enum CardCatalog {
    private static let chase: UInt32 = 0x1F5BC4
    private static let amex: UInt32 = 0x2A6F8E
    private static let capitalOne: UInt32 = 0xB02A37
    private static let citi: UInt32 = 0x3D5A99
    private static let discover: UInt32 = 0xD9731A
    private static let wellsFargo: UInt32 = 0x9C2B2B
    private static let bankOfAmerica: UInt32 = 0x0C4A8F
    private static let apple: UInt32 = 0x4A4A52

    // Each card has the `issuerID` of its issuer, which names the logo bundled in the app. The Apple Card
    // has none: its bank in opencard-db is Goldman Sachs, and it should not show that bank's logo.
    // `logoDomain` is the fallback, a website to load a logo from LogoAPI.sh.
    static let all: [CatalogCard] = [
        CatalogCard(id: "us-chase-freedom-unlimited", name: "Chase Freedom Unlimited", issuer: "Chase", badgeCode: "CH", badgeColorHex: chase, issuerID: "chase"),
        CatalogCard(id: "us-chase-sapphire-preferred", name: "Chase Sapphire Preferred", issuer: "Chase", badgeCode: "CH", badgeColorHex: chase, issuerID: "chase"),
        CatalogCard(id: "us-chase-freedom-flex", name: "Chase Freedom Flex", issuer: "Chase", badgeCode: "CH", badgeColorHex: chase, issuerID: "chase"),
        CatalogCard(id: "us-amex-gold", name: "American Express Gold Card", issuer: "American Express", badgeCode: "AX", badgeColorHex: amex, logoDomain: "americanexpress.com", issuerID: "amex"),
        CatalogCard(id: "us-amex-blue-cash-everyday", name: "Blue Cash Everyday", issuer: "American Express", badgeCode: "AX", badgeColorHex: amex, logoDomain: "americanexpress.com", issuerID: "amex"),
        CatalogCard(id: "us-capital-one-quicksilver", name: "Capital One Quicksilver", issuer: "Capital One", badgeCode: "C1", badgeColorHex: capitalOne, logoDomain: "capitalone.com", issuerID: "capital-one"),
        CatalogCard(id: "us-capital-one-venture", name: "Capital One Venture", issuer: "Capital One", badgeCode: "C1", badgeColorHex: capitalOne, logoDomain: "capitalone.com", issuerID: "capital-one"),
        CatalogCard(id: "us-citi-double-cash", name: "Citi Double Cash", issuer: "Citi", badgeCode: "CI", badgeColorHex: citi, issuerID: "citi"),
        CatalogCard(id: "us-citi-custom-cash", name: "Citi Custom Cash", issuer: "Citi", badgeCode: "CI", badgeColorHex: citi, issuerID: "citi"),
        CatalogCard(id: "us-discover-it-cash-back", name: "Discover it Cash Back", issuer: "Discover", badgeCode: "DI", badgeColorHex: discover, logoDomain: "discover.com", issuerID: "discover"),
        CatalogCard(id: "us-wells-fargo-active-cash", name: "Wells Fargo Active Cash", issuer: "Wells Fargo", badgeCode: "WF", badgeColorHex: wellsFargo, logoDomain: "wellsfargo.com", issuerID: "wells-fargo"),
        CatalogCard(id: "us-bank-of-america-customized-cash-rewards", name: "Bank of America Customized Cash Rewards", issuer: "Bank of America", badgeCode: "BA", badgeColorHex: bankOfAmerica, logoDomain: "bankofamerica.com", issuerID: "bank-of-america"),
        CatalogCard(id: "us-apple-card", name: "Apple Card", issuer: "Apple", badgeCode: "AP", badgeColorHex: apple, logoDomain: "apple.com"),
    ]

    static func card(withID id: String) -> CatalogCard? {
        all.first { $0.id == id }
    }

    /// Cards in the built-in list whose name or issuer contains `query`.
    static func cards(matching query: String) -> [CatalogCard] {
        search(all, matching: query)
    }

    /// The cards in `cards` whose name or issuer contains `query` (ignoring case and accents). An empty
    /// query returns all of them.
    static func search(_ cards: [CatalogCard], matching query: String) -> [CatalogCard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return cards }
        return cards.filter {
            $0.name.localizedStandardContains(trimmed) || $0.issuer.localizedStandardContains(trimmed)
        }
    }
}
