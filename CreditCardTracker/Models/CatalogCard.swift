import Foundation

/// A card the user can pick during onboarding, e.g. "Chase Sapphire Preferred".
///
/// For now these come from the hard-coded `CardCatalog`. Later they can come from a free card
/// catalog (CardFacts / opencard-db).
struct CatalogCard: Identifiable, Hashable {
    /// Stable ID, e.g. "chase-sapphire-preferred".
    let id: String
    let name: String
    let issuer: String
    /// Two or three letters shown in the colored badge, e.g. "CH".
    let badgeCode: String
    /// Badge color as 0xRRGGBB. Kept as a number so the model has no UI dependency.
    let badgeColorHex: UInt32
}

// MARK: - Custom cards

/// A card the user adds by name because it is not in the catalog ("My card is not listed").
extension CatalogCard {
    static let customIDPrefix = "custom-"

    var isCustom: Bool { id.hasPrefix(Self.customIDPrefix) }

    /// A custom card. The badge shows the initials of the name, or "?" while there is no name yet.
    static func custom(
        id: String = CatalogCard.customIDPrefix + UUID().uuidString,
        name: String
    ) -> CatalogCard {
        CatalogCard(
            id: id,
            name: name,
            issuer: "Custom card",
            badgeCode: initials(for: name),
            badgeColorHex: 0x5B4CF0
        )
    }

    /// "Navy Federal" gives "NF", "Costco" gives "CO", and no name gives "?".
    static func initials(for name: String) -> String {
        let words = name.split(whereSeparator: \.isWhitespace)
        let letters: [Character]
        if words.count >= 2 {
            letters = words.prefix(2).compactMap(\.first)
        } else if let word = words.first {
            letters = Array(word.prefix(2))
        } else {
            return "?"
        }
        return String(letters).uppercased()
    }
}
