import XCTest
@testable import CreditCardTracker

/// The Pay button's links: only https, only on the lender's own website, and the button always names the
/// lender it opens.
final class PayLinksTests: XCTestCase {
    /// Each lender's issuer ID, the name on the button, and the website its link must stay on.
    private let lenders: [String: (name: String, domain: String)] = [
        "chase": ("Chase", "chase.com"),
        "amex": ("American Express", "americanexpress.com"),
        "barclays": ("Barclays", "barclaysus.com"),
        "us-bank": ("U.S. Bank", "usbank.com"),
        "synchrony": ("Synchrony", "synchrony.com"),
        "capital-one": ("Capital One", "capitalone.com"),
        "bank-of-america": ("Bank of America", "bankofamerica.com"),
        "citi": ("Citi", "citi.com"),
        "wells-fargo": ("Wells Fargo", "wellsfargo.com"),
        "discover": ("Discover", "discover.com"),
        "usaa": ("USAA", "usaa.com"),
        "navy-federal": ("Navy Federal", "navyfederal.org"),
        "credit-one-bank": ("Credit One", "creditonebank.com"),
        "truist": ("Truist", "truist.com"),
        "citizens": ("Citizens", "citizensbank.com"),
        "fnbo": ("FNBO", "fnbo.com"),
    ]

    private func catalogCard(issuer: String, issuerID: String?) -> CatalogCard {
        CatalogCard(id: "test-\(issuer)", name: "Some Card", issuer: issuer, badgeCode: "XX", badgeColorHex: 0, issuerID: issuerID)
    }

    func testTheListHasExactlyTheseLenders() {
        XCTAssertEqual(Set(PayLinks.banks.keys), Set(lenders.keys))
    }

    func testEveryLenderIsNamedOnItsButton() {
        for (issuerID, expected) in lenders {
            XCTAssertEqual(PayLinks.bank(forIssuerID: issuerID)?.name, expected.name, issuerID)
            XCTAssertEqual(PayLinks.bank(forIssuerID: issuerID)?.buttonTitle, "Pay \(expected.name)", issuerID)
        }
    }

    func testEveryLinkIsHTTPS() {
        for issuerID in lenders.keys {
            let url = PayLinks.url(forIssuerID: issuerID)
            XCTAssertNotNil(url, issuerID)
            XCTAssertEqual(url?.scheme, "https", issuerID)
        }
    }

    func testEveryLinkStaysOnTheLendersOwnWebsite() throws {
        for (issuerID, expected) in lenders {
            let host = try XCTUnwrap(PayLinks.url(forIssuerID: issuerID)?.host, issuerID)
            XCTAssertTrue(host == expected.domain || host.hasSuffix("." + expected.domain), "\(issuerID) opens \(host)")
        }
    }

    func testNoLenderSharesAnotherLendersPage() {
        let hosts = PayLinks.banks.keys.compactMap { PayLinks.url(forIssuerID: $0)?.host }
        XCTAssertEqual(hosts.count, Set(hosts).count)
    }

    func testNoLinkCarriesAPersonalDetail() {
        // The app only opens the lender's page. Nothing about the user goes in the address.
        for issuerID in lenders.keys {
            let url = PayLinks.url(forIssuerID: issuerID)
            XCTAssertNil(url?.user, issuerID)
            XCTAssertNil(url?.password, issuerID)
            XCTAssertNil(url?.fragment, issuerID)
        }
    }

    func testAnAddressThatIsNotHTTPSIsNeverUsed() {
        XCTAssertNil(PayLinks.Bank(name: "Test", address: "http://www.example.com/").url)
        XCTAssertNil(PayLinks.Bank(name: "Test", address: "ftp://www.example.com/").url)
        XCTAssertNil(PayLinks.Bank(name: "Test", address: "not a link").url)
        XCTAssertNotNil(PayLinks.Bank(name: "Test", address: "https://www.example.com/").url)
    }

    func testAnUnknownLenderHasNoLink() {
        XCTAssertNil(PayLinks.url(forIssuerID: "some-credit-union"))
        XCTAssertNil(PayLinks.bank(forIssuerID: ""))
    }

    func testACardGetsItsOwnLendersNameAndLink() throws {
        for (issuerID, expected) in lenders {
            let card = catalogCard(issuer: expected.name, issuerID: issuerID)
            XCTAssertEqual(PayLinks.buttonTitle(for: card), "Pay \(expected.name)", issuerID)
            XCTAssertEqual(PayLinks.url(for: card), PayLinks.url(forIssuerID: issuerID), issuerID)
        }
    }

    func testTheButtonNamesTheLenderThatIssuedTheCardNotTheBrandOnIt() {
        // An Amazon, United or Marriott card is issued by Chase: Chase is who gets paid. A USAA card on
        // the American Express network is paid to USAA.
        XCTAssertEqual(PayLinks.buttonTitle(for: catalogCard(issuer: "Chase", issuerID: "chase")), "Pay Chase")
        XCTAssertEqual(PayLinks.buttonTitle(for: catalogCard(issuer: "USAA Federal Savings Bank", issuerID: "usaa")), "Pay USAA")
        XCTAssertEqual(PayLinks.buttonTitle(for: catalogCard(issuer: "Citi", issuerID: "citi")), "Pay Citi")
    }

    func testNotListedCardsAndCardsWithoutALenderIdHaveNoLinkOrLenderName() {
        let custom = CatalogCard.custom(name: "Chase Navy Federal Go")
        XCTAssertNil(PayLinks.url(for: custom))
        XCTAssertNil(PayLinks.bank(for: custom))
        XCTAssertEqual(PayLinks.buttonTitle(for: custom), "Pay")

        let noID = catalogCard(issuer: "Apple", issuerID: nil)
        XCTAssertNil(PayLinks.url(for: noID))
        XCTAssertEqual(PayLinks.buttonTitle(for: noID), "Pay")
    }

    func testEveryBuiltInCardWithALinkNamesItsOwnLender() {
        // The 13 built-in cards: the button for each one must name that card's own issuer.
        for card in CardCatalog.all {
            guard let bank = PayLinks.bank(for: card) else { continue }
            XCTAssertEqual(bank.name, card.issuer, "\(card.name) would show \(bank.buttonTitle)")
        }
    }
}
