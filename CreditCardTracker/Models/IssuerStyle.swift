import Foundation

/// How a card's badge looks: the letters, the color, and the website its logo is looked up by.
struct BadgeStyle: Equatable {
    var code: String
    var colorHex: UInt32
    var logoDomain: String?
}

/// Picks the badge for a card. The card list has names and issuers but no artwork, so the badge
/// comes from the issuer: a known color for the biggest banks, and a steady color made from the
/// issuer's ID for everyone else (the same issuer always gets the same color).
enum IssuerStyle {
    /// Issuers listed first, in this order. Everyone else follows alphabetically.
    static let priorityIssuerIDs = [
        "chase", "amex", "capital-one", "citi", "discover",
        "wells-fargo", "bank-of-america", "us-bank", "barclays", "synchrony",
    ]

    static func priority(of issuerID: String) -> Int {
        priorityIssuerIDs.firstIndex(of: issuerID) ?? priorityIssuerIDs.count
    }

    static func style(forIssuerID id: String, issuerName: String) -> BadgeStyle {
        let brand = brandStyles[id]
        return BadgeStyle(
            code: brand?.code ?? codeOverrides[id] ?? fallbackCode(forIssuerName: issuerName),
            colorHex: brand?.colorHex ?? fallbackColor(forIssuerID: id),
            logoDomain: logoDomains[id]
        )
    }

    /// A card that does not look like its issuer. Apple Card is issued by Goldman Sachs.
    static func style(forCardID id: String, issuerID: String, issuerName: String) -> BadgeStyle {
        cardOverrides[id] ?? style(forIssuerID: issuerID, issuerName: issuerName)
    }

    /// True for a card that has its own look (see `cardOverrides`). Such a card must not pick up a logo
    /// bundled for its issuer: the Apple Card would show Goldman Sachs' logo.
    static func hasOwnStyle(forCardID id: String) -> Bool {
        cardOverrides[id] != nil
    }

    // MARK: Known issuers

    /// Colors the app already used for these issuers.
    private static let brandStyles: [String: (code: String, colorHex: UInt32)] = [
        "chase": ("CH", 0x1F5BC4),
        "amex": ("AX", 0x2A6F8E),
        "capital-one": ("C1", 0xB02A37),
        "citi": ("CI", 0x3D5A99),
        "discover": ("DI", 0xD9731A),
        "wells-fargo": ("WF", 0x9C2B2B),
        "bank-of-america": ("BA", 0x0C4A8F),
    ]

    /// Letters that the general rule gets wrong ("U.S. Bank" would become "UB") or would share with a
    /// bigger issuer ("Barclays" and "Citizens" would look like Bank of America and Citi).
    private static let codeOverrides: [String: String] = [
        "us-bank": "US",
        "usaa": "UA",
        "td": "TD",
        "barclays": "BC",
        "citizens": "CZ",
    ]

    /// The issuer's website, used to ask LogoAPI.sh for its logo. This is the second choice: a logo
    /// bundled in the app (`BundledLogo`) wins. Chase and Citi are left out because LogoAPI.sh does not
    /// have them. Only Synchrony is confirmed to be in LogoAPI.sh among the issuers with no bundled
    /// logo; for the others (PenFed, BMO, Credit One, FNBO) the colored badge stays if it is not found.
    private static let logoDomains: [String: String] = [
        "amex": "americanexpress.com",
        "capital-one": "capitalone.com",
        "discover": "discover.com",
        "wells-fargo": "wellsfargo.com",
        "bank-of-america": "bankofamerica.com",
        "us-bank": "usbank.com",
        "barclays": "barclays.com",
        "synchrony": "synchrony.com",
        "navy-federal": "navyfederal.org",
        "usaa": "usaa.com",
        "td": "td.com",
        "truist": "truist.com",
        "pnc": "pnc.com",
        "sofi": "sofi.com",
        "citizens": "citizensbank.com",
        "penfed": "penfed.org",
        "fifth-third": "53.com",
        "regions": "regions.com",
        "bmo": "bmo.com",
        "hsbc": "hsbc.com",
        "credit-one-bank": "creditonebank.com",
        "fnbo": "fnbo.com",
    ]

    private static let cardOverrides: [String: BadgeStyle] = [
        "us-apple-card": BadgeStyle(code: "AP", colorHex: 0x4A4A52, logoDomain: "apple.com"),
    ]

    // MARK: Everyone else

    /// Muted colors that keep white text readable (each has a contrast ratio of at least 4.5).
    static let palette: [UInt32] = [
        0x2F5FD0, 0x6D4AC4, 0x0E7C66, 0xC2410C, 0xA8327E, 0x0F7490, 0x5B6472, 0x9A3412,
        0x3A6B35, 0x8A4B08, 0x1D6FA3, 0x7A3B8F, 0xB4233A, 0x2E6F6B, 0x5C4DB1, 0x8C5A00,
    ]

    static func fallbackColor(forIssuerID id: String) -> UInt32 {
        palette[Int(stableHash(id) % UInt64(palette.count))]
    }

    /// Two letters for the badge: the first letters of the first two words ("Navy Federal Credit
    /// Union" is "NF"), or the first two letters of a single word ("SoFi" is "SO").
    static func fallbackCode(forIssuerName name: String) -> String {
        let words = name
            .split(whereSeparator: \.isWhitespace)
            .map { $0.filter(\.isLetter) }
            .filter { !$0.isEmpty }
        guard let first = words.first else { return "?" }
        let code = words.count >= 2 ? String(first.prefix(1)) + String(words[1].prefix(1)) : String(first.prefix(2))
        return code.uppercased()
    }

    /// FNV-1a. Swift's own `hashValue` changes every launch, which would change the colors every launch.
    static func stableHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01b3
        }
        return hash
    }
}
