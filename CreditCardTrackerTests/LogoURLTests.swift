import UIKit
import XCTest
@testable import CreditCardTracker

final class LogoURLTests: XCTestCase {
    func testIconURLAsksForAPngAndA404WhenMissing() {
        let url = LogoService.iconURL(forDomain: "capitalone.com")
        XCTAssertEqual(url?.absoluteString, "https://logoapi.sh/icon/capitalone.com.png?size=256&fallback=404")
    }

    func testListedIssuersHaveALogoURL() throws {
        let card = try XCTUnwrap(CardCatalog.card(withID: "us-capital-one-quicksilver"))
        XCTAssertEqual(card.logoURL?.host, "logoapi.sh")
        XCTAssertEqual(card.logoURL?.path, "/icon/capitalone.com.png")
    }

    func testIssuersMissingFromTheServiceKeepTheirBadge() throws {
        // Chase and Citi are not in LogoAPI.sh, so no request is made for them.
        XCTAssertNil(try XCTUnwrap(CardCatalog.card(withID: "us-chase-sapphire-preferred")).logoURL)
        XCTAssertNil(try XCTUnwrap(CardCatalog.card(withID: "us-citi-double-cash")).logoURL)
    }

    func testNotListedCardsHaveNoLogo() {
        XCTAssertNil(CatalogCard.custom(name: "Navy Federal").logoURL)
    }

    func testEveryLogoURLIsHTTPSOnTheLogoService() {
        for card in CardCatalog.all {
            guard let url = card.logoURL else { continue }
            XCTAssertEqual(url.scheme, "https", card.name)
            XCTAssertEqual(url.host, "logoapi.sh", card.name)
        }
    }
}

// MARK: - Logos bundled in the app

final class BundledLogoTests: XCTestCase {
    /// Every logo image set in `Assets.xcassets/IssuerLogos`. Keep in step with docs/issuer-logos.md.
    private let bundledIssuerIDs = [
        "amex", "bank-of-america", "barclays", "brex", "capital-one", "cfna", "chase", "citi", "citizens",
        "cross-river-bank", "discover", "fifth-third", "goldman-sachs", "hsbc", "navy-federal",
        "patriot-bank", "pnc", "regions", "sofi", "td", "truist", "ubs", "us-bank", "usaa", "wells-fargo",
    ]

    private func card(issuerID: String?) -> CatalogCard {
        CatalogCard(id: "us-test", name: "Test Card", issuer: "Test", badgeCode: "TC", badgeColorHex: 0x123456,
                    issuerID: issuerID)
    }

    func testTheLogoNameIsBuiltFromTheIssuerID() {
        XCTAssertEqual(card(issuerID: "chase").bundledLogoName, "logo-chase")
        XCTAssertNil(card(issuerID: nil).bundledLogoName)
    }

    func testEveryListedLogoIsReallyInTheApp() {
        for id in bundledIssuerIDs {
            XCTAssertNotNil(UIImage(named: "logo-\(id)"), "logo-\(id) is missing from the asset catalog")
        }
    }

    func testAnIssuerWeHaveALogoForGetsIt() {
        XCTAssertEqual(BundledLogo.imageName(for: card(issuerID: "chase")), "logo-chase")
        XCTAssertEqual(BundledLogo.imageName(for: card(issuerID: "us-bank")), "logo-us-bank")
    }

    func testAnIssuerWithoutALogoGetsNone() {
        // The name is built, but no image has it, so the card falls back to LogoAPI.sh or the badge.
        XCTAssertEqual(card(issuerID: "synchrony").bundledLogoName, "logo-synchrony")
        XCTAssertNil(BundledLogo.imageName(for: card(issuerID: "synchrony")))
        XCTAssertNil(BundledLogo.imageName(for: card(issuerID: nil)))
        XCTAssertNil(BundledLogo.imageName(for: CatalogCard.custom(name: "Navy Federal")))
    }

    func testBuiltInCardsFindTheirLogo() throws {
        XCTAssertEqual(BundledLogo.imageName(for: try XCTUnwrap(CardCatalog.card(withID: "us-chase-sapphire-preferred"))),
                       "logo-chase")
        XCTAssertEqual(BundledLogo.imageName(for: try XCTUnwrap(CardCatalog.card(withID: "us-citi-double-cash"))),
                       "logo-citi")
    }

    func testAppleCardDoesNotBorrowGoldmanSachsLogo() throws {
        let apple = try XCTUnwrap(CardCatalog.card(withID: "us-apple-card"))
        XCTAssertNil(apple.issuerID)
        XCTAssertNil(BundledLogo.imageName(for: apple))
    }
}
