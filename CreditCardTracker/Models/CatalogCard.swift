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

// MARK: - Cards that are not listed

/// A card the user added with "My card is not listed". The user types its name on the card form.
extension CatalogCard {
    static let customIDPrefix = "custom-"
    /// What an unnamed not-listed card is called.
    static let defaultCustomName = "Other card"

    var isCustom: Bool { id.hasPrefix(Self.customIDPrefix) }

    static func custom(
        id: String = CatalogCard.customIDPrefix + UUID().uuidString,
        name: String = ""
    ) -> CatalogCard {
        CatalogCard(id: id, name: name, issuer: "Not listed", badgeCode: "", badgeColorHex: 0x6B6B78)
    }

    /// The name to show. A not-listed card left unnamed is shown as "Other card".
    var displayName: String {
        guard isCustom else { return name }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultCustomName : trimmed
    }
}
