import Foundation

/// Where the "Pay" button sends the user: the bank's own web page, where they sign in and pay.
///
/// The app opens the link with the phone's normal link handling. That shows the page in Safari, or
/// opens the bank's app when it is installed and the bank has set that link up to open in its app.
/// The app never sees a password or a card number, and it never makes the payment itself.
///
/// This is a hand-made list for the nine biggest card banks. A card whose bank is not here has no
/// Pay button. To add a bank, add its issuer ID (the `issuerID` of its cards) and its https address.
enum PayLinks {
    /// Issuer ID to the page that opens. Pages that go straight to a sign-in form are used where the bank
    /// has one that stays put; otherwise the bank's home page, which has a "Log in" link at the top.
    static let addresses: [String: String] = [
        "chase": "https://www.chase.com/personal/credit-cards/login-account-access",
        "amex": "https://www.americanexpress.com/",
        "barclays": "https://www.barclaysus.com/",
        "us-bank": "https://www.usbank.com/",
        "synchrony": "https://www.synchrony.com/login",
        "capital-one": "https://verified.capitalone.com/auth/signin",
        "bank-of-america": "https://www.bankofamerica.com/",
        "citi": "https://www.citi.com/",
        "wells-fargo": "https://connect.secure.wellsfargo.com/auth/login/present?origin=cob",
    ]

    /// The page to open for an issuer. Nil when the bank is not in the list, and nil for any address
    /// that is not https, so a typo in the list can never open an insecure page.
    static func url(forIssuerID issuerID: String) -> URL? {
        guard let address = addresses[issuerID],
              let url = URL(string: address),
              url.scheme == "https",
              url.host != nil
        else { return nil }
        return url
    }

    /// The page to open for a card. Nil for not-listed cards and for banks without a link.
    static func url(for card: CatalogCard) -> URL? {
        guard let issuerID = card.issuerID else { return nil }
        return url(forIssuerID: issuerID)
    }

    /// The text on the big Pay button: "Pay Chase". A long bank name would not fit beside the card
    /// name, so those just say "Pay".
    static func buttonTitle(for card: CatalogCard) -> String {
        let bank = card.issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bank.isEmpty, bank.count <= 12 else { return "Pay" }
        return "Pay \(bank)"
    }
}
