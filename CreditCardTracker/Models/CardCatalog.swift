import Foundation

/// Temporary hard-coded card list for the "Pick your cards" screen.
enum CardCatalog {
    private static let chase: UInt32 = 0x1F5BC4
    private static let amex: UInt32 = 0x2A6F8E
    private static let capitalOne: UInt32 = 0xB02A37
    private static let citi: UInt32 = 0x3D5A99
    private static let discover: UInt32 = 0xD9731A
    private static let wellsFargo: UInt32 = 0x9C2B2B
    private static let bankOfAmerica: UInt32 = 0x0C4A8F
    private static let apple: UInt32 = 0x4A4A52

    static let all: [CatalogCard] = [
        CatalogCard(id: "chase-freedom-unlimited", name: "Chase Freedom Unlimited", issuer: "Chase", badgeCode: "CH", badgeColorHex: chase),
        CatalogCard(id: "chase-sapphire-preferred", name: "Chase Sapphire Preferred", issuer: "Chase", badgeCode: "CH", badgeColorHex: chase),
        CatalogCard(id: "chase-freedom-flex", name: "Chase Freedom Flex", issuer: "Chase", badgeCode: "CH", badgeColorHex: chase),
        CatalogCard(id: "amex-gold-card", name: "American Express Gold Card", issuer: "American Express", badgeCode: "AX", badgeColorHex: amex),
        CatalogCard(id: "amex-blue-cash-everyday", name: "Blue Cash Everyday", issuer: "American Express", badgeCode: "AX", badgeColorHex: amex),
        CatalogCard(id: "capital-one-quicksilver", name: "Capital One Quicksilver", issuer: "Capital One", badgeCode: "C1", badgeColorHex: capitalOne),
        CatalogCard(id: "capital-one-venture", name: "Capital One Venture", issuer: "Capital One", badgeCode: "C1", badgeColorHex: capitalOne),
        CatalogCard(id: "citi-double-cash", name: "Citi Double Cash", issuer: "Citi", badgeCode: "CI", badgeColorHex: citi),
        CatalogCard(id: "citi-custom-cash", name: "Citi Custom Cash", issuer: "Citi", badgeCode: "CI", badgeColorHex: citi),
        CatalogCard(id: "discover-it-cash-back", name: "Discover it Cash Back", issuer: "Discover", badgeCode: "DI", badgeColorHex: discover),
        CatalogCard(id: "wells-fargo-active-cash", name: "Wells Fargo Active Cash", issuer: "Wells Fargo", badgeCode: "WF", badgeColorHex: wellsFargo),
        CatalogCard(id: "bank-of-america-customized-cash", name: "Bank of America Customized Cash Rewards", issuer: "Bank of America", badgeCode: "BA", badgeColorHex: bankOfAmerica),
        CatalogCard(id: "apple-card", name: "Apple Card", issuer: "Apple", badgeCode: "AP", badgeColorHex: apple),
    ]

    static func card(withID id: String) -> CatalogCard? {
        all.first { $0.id == id }
    }

    /// Cards whose name or issuer contains `query` (ignoring case and accents). An empty query returns everything.
    static func cards(matching query: String) -> [CatalogCard] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return all }
        return all.filter {
            $0.name.localizedStandardContains(trimmed) || $0.issuer.localizedStandardContains(trimmed)
        }
    }
}
