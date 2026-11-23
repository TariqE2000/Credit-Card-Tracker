import XCTest
@testable import CreditCardTracker

final class LogoURLTests: XCTestCase {
    func testIconURLAsksForAPngAndA404WhenMissing() {
        let url = LogoService.iconURL(forDomain: "capitalone.com")
        XCTAssertEqual(url?.absoluteString, "https://logoapi.sh/icon/capitalone.com.png?size=256&fallback=404")
    }

    func testListedIssuersHaveALogoURL() throws {
        let card = try XCTUnwrap(BuiltInIssuers.card(withID: "us-capital-one-quicksilver"))
        XCTAssertEqual(card.logoURL?.host, "logoapi.sh")
        XCTAssertEqual(card.logoURL?.path, "/icon/capitalone.com.png")
    }

    func testIssuersMissingFromTheServiceKeepTheirBadge() throws {
        // Chase and Citi are not in LogoAPI.sh, so no request is made for them.
        XCTAssertNil(try XCTUnwrap(BuiltInIssuers.card(withID: "us-chase-sapphire-preferred")).logoURL)
        XCTAssertNil(try XCTUnwrap(BuiltInIssuers.card(withID: "us-citi-double-cash")).logoURL)
    }

    func testNotListedCardsHaveNoLogo() {
        XCTAssertNil(Issuer.custom(name: "Navy Federal").logoURL)
    }

    func testEveryLogoURLIsHTTPSOnTheLogoService() {
        for card in BuiltInIssuers.all {
            guard let url = card.logoURL else { continue }
            XCTAssertEqual(url.scheme, "https", card.name)
            XCTAssertEqual(url.host, "logoapi.sh", card.name)
        }
    }
}
