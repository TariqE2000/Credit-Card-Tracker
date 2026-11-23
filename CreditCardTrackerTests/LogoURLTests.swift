import XCTest
@testable import CreditCardTracker

final class LogoURLTests: XCTestCase {
    func testIconURLAsksForAPngAndA404WhenMissing() {
        let url = LogoService.iconURL(forDomain: "capitalone.com")
        XCTAssertEqual(url?.absoluteString, "https://logoapi.sh/icon/capitalone.com.png?size=256&fallback=404")
    }

    func testListedIssuersHaveALogoURL() throws {
        let card = try XCTUnwrap(CardCatalog.card(withID: "capital-one-quicksilver"))
        XCTAssertEqual(card.logoURL?.host, "logoapi.sh")
        XCTAssertEqual(card.logoURL?.path, "/icon/capitalone.com.png")
    }

    func testIssuersMissingFromTheServiceKeepTheirBadge() throws {
        // Chase and Citi are not in LogoAPI.sh, so no request is made for them.
        XCTAssertNil(try XCTUnwrap(CardCatalog.card(withID: "chase-sapphire-preferred")).logoURL)
        XCTAssertNil(try XCTUnwrap(CardCatalog.card(withID: "citi-double-cash")).logoURL)
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
