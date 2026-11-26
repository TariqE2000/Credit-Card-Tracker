import XCTest
@testable import CreditCardTracker

/// The Pay button's links: only the nine biggest banks, only https, and only on the bank's own website.
final class PayLinksTests: XCTestCase {
    /// Each bank's issuer ID and the website its link must stay on.
    private let banks: [String: String] = [
        "chase": "chase.com",
        "amex": "americanexpress.com",
        "barclays": "barclaysus.com",
        "us-bank": "usbank.com",
        "synchrony": "synchrony.com",
        "capital-one": "capitalone.com",
        "bank-of-america": "bankofamerica.com",
        "citi": "citi.com",
        "wells-fargo": "wellsfargo.com",
    ]

    func testTheNineBiggestBanksHaveALink() {
        XCTAssertEqual(Set(PayLinks.addresses.keys), Set(banks.keys))
    }

    func testEveryLinkIsHTTPS() {
        for issuerID in banks.keys {
            let url = PayLinks.url(forIssuerID: issuerID)
            XCTAssertNotNil(url, issuerID)
            XCTAssertEqual(url?.scheme, "https", issuerID)
        }
    }

    func testEveryLinkStaysOnTheBanksOwnWebsite() throws {
        for (issuerID, domain) in banks {
            let host = try XCTUnwrap(PayLinks.url(forIssuerID: issuerID)?.host, issuerID)
            XCTAssertTrue(host == domain || host.hasSuffix("." + domain), "\(issuerID) opens \(host)")
        }
    }

    func testNoLinkCarriesAPersonalDetail() {
        // The app only opens the bank's page. Nothing about the user goes in the address.
        for issuerID in banks.keys {
            let url = PayLinks.url(forIssuerID: issuerID)
            XCTAssertNil(url?.user, issuerID)
            XCTAssertNil(url?.password, issuerID)
            XCTAssertNil(url?.fragment, issuerID)
        }
    }

    func testAnUnknownBankHasNoLink() {
        XCTAssertNil(PayLinks.url(forIssuerID: "some-credit-union"))
        XCTAssertNil(PayLinks.url(forIssuerID: ""))
    }

    func testACardGetsItsBanksLink() {
        let card = CatalogCard(
            id: "us-chase-sapphire-preferred", name: "Sapphire Preferred", issuer: "Chase",
            badgeCode: "CH", badgeColorHex: 0x1F5BC4, issuerID: "chase"
        )
        XCTAssertEqual(PayLinks.url(for: card), PayLinks.url(forIssuerID: "chase"))
    }

    func testNotListedCardsAndCardsWithoutABankIdHaveNoLink() {
        XCTAssertNil(PayLinks.url(for: CatalogCard.custom(name: "Navy Federal Go")))
        let noID = CatalogCard(id: "x", name: "X", issuer: "X", badgeCode: "X", badgeColorHex: 0)
        XCTAssertNil(PayLinks.url(for: noID))
    }

    func testButtonTitleNamesTheBankUnlessItIsLong() {
        func title(_ issuer: String) -> String {
            PayLinks.buttonTitle(
                for: CatalogCard(id: "x", name: "X", issuer: issuer, badgeCode: "X", badgeColorHex: 0)
            )
        }
        XCTAssertEqual(title("Chase"), "Pay Chase")
        XCTAssertEqual(title("Capital One"), "Pay Capital One")
        XCTAssertEqual(title("Wells Fargo"), "Pay Wells Fargo")
        XCTAssertEqual(title("Bank of America"), "Pay")
        XCTAssertEqual(title("American Express"), "Pay")
        XCTAssertEqual(title("  "), "Pay")
    }
}
