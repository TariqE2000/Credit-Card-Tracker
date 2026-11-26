import Foundation

/// Where the "Pay" button sends the user: the lender's own web page, where they sign in and pay.
///
/// Each entry holds the lender's name and its page together, so the button always names the lender it
/// opens: "Pay Chase" opens Chase, "Pay Citi" opens Citi. A co-branded card (an Amazon, United or
/// Marriott card issued by Chase, say) pays the lender that issued it, which is what the card list's
/// `issuerID` records.
///
/// The app opens the link with the phone's normal link handling. That shows the page in Safari, or
/// opens the lender's app when it is installed and the lender has set that link up to open in its app.
/// The app never sees a password or a card number, and it never makes the payment itself.
///
/// This is a hand-made list. A card whose lender is not here has no Pay button. To add a lender, add its
/// issuer ID (the `issuerID` of its cards) with its name and https address.
enum PayLinks {
    /// One lender: the name shown on the button and the page it opens.
    struct Bank: Equatable {
        /// "Chase", "Capital One". Shown as "Pay Chase".
        let name: String
        let address: String

        /// The page to open. Nil for any address that is not https, so a typo in the list can never
        /// open an insecure page.
        var url: URL? {
            guard let url = URL(string: address), url.scheme == "https", url.host != nil else { return nil }
            return url
        }

        /// "Pay Chase"
        var buttonTitle: String { "Pay \(name)" }
    }

    /// Issuer ID to lender. Pages that go straight to a sign-in form are used where the lender has one
    /// that stays put; otherwise the lender's home page, which has a log in link at the top.
    static let banks: [String: Bank] = [
        "chase": Bank(name: "Chase", address: "https://www.chase.com/personal/credit-cards/login-account-access"),
        "amex": Bank(name: "American Express", address: "https://www.americanexpress.com/"),
        "barclays": Bank(name: "Barclays", address: "https://www.barclaysus.com/"),
        "us-bank": Bank(name: "U.S. Bank", address: "https://www.usbank.com/"),
        "synchrony": Bank(name: "Synchrony", address: "https://www.synchrony.com/login"),
        "capital-one": Bank(name: "Capital One", address: "https://verified.capitalone.com/auth/signin"),
        "bank-of-america": Bank(name: "Bank of America", address: "https://www.bankofamerica.com/"),
        "citi": Bank(name: "Citi", address: "https://www.citi.com/"),
        "wells-fargo": Bank(
            name: "Wells Fargo",
            address: "https://connect.secure.wellsfargo.com/auth/login/present?origin=cob"
        ),
        "discover": Bank(name: "Discover", address: "https://www.discover.com/"),
        "usaa": Bank(name: "USAA", address: "https://www.usaa.com/"),
        "navy-federal": Bank(name: "Navy Federal", address: "https://www.navyfederal.org/"),
        "credit-one-bank": Bank(name: "Credit One", address: "https://www.creditonebank.com/"),
        "truist": Bank(name: "Truist", address: "https://www.truist.com/"),
        "citizens": Bank(name: "Citizens", address: "https://www.citizensbank.com/"),
        "fnbo": Bank(name: "FNBO", address: "https://www.fnbo.com/"),
    ]

    /// The lender for an issuer ID. Nil when the lender is not in the list, or its address is not a
    /// valid https address, so a button never names a lender it cannot open.
    static func bank(forIssuerID issuerID: String) -> Bank? {
        guard let bank = banks[issuerID], bank.url != nil else { return nil }
        return bank
    }

    /// The lender for a card. Nil for not-listed cards and for lenders without a link.
    static func bank(for card: CatalogCard) -> Bank? {
        guard let issuerID = card.issuerID else { return nil }
        return bank(forIssuerID: issuerID)
    }

    /// The page to open for an issuer ID.
    static func url(forIssuerID issuerID: String) -> URL? {
        bank(forIssuerID: issuerID)?.url
    }

    /// The page to open for a card.
    static func url(for card: CatalogCard) -> URL? {
        bank(for: card)?.url
    }

    /// The text on the Pay button: "Pay Chase". Plain "Pay" for a card with no lender in the list.
    static func buttonTitle(for card: CatalogCard) -> String {
        bank(for: card)?.buttonTitle ?? "Pay"
    }
}
