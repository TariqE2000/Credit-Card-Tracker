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
