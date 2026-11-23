import XCTest
@testable import CreditCardTracker

final class LogoURLTests: XCTestCase {
    func testIconURLAsksForAPngAndA404WhenMissing() {
        let url = LogoService.iconURL(forDomain: "capitalone.com")
        XCTAssertEqual(url?.absoluteString, "https://logoapi.sh/icon/capitalone.com.png?size=256&fallback=404")
    }

    func testListedIssuersHaveALogoURL() throws {
        let issuer = try XCTUnwrap(BuiltInIssuers.issuer(withID: "capital-one"))
        XCTAssertEqual(issuer.logoURL?.host, "logoapi.sh")
        XCTAssertEqual(issuer.logoURL?.path, "/icon/capitalone.com.png")
    }

    func testIssuersMissingFromTheServiceKeepTheirBadge() throws {
        // Chase and Citi are not in LogoAPI.sh, so no request is made for them.
        XCTAssertNil(try XCTUnwrap(BuiltInIssuers.issuer(withID: "chase")).logoURL)
        XCTAssertNil(try XCTUnwrap(BuiltInIssuers.issuer(withID: "citi")).logoURL)
    }

    func testNotListedBanksHaveNoLogo() {
        XCTAssertNil(Issuer.custom(name: "Navy Federal").logoURL)
    }

    func testEveryLogoURLIsHTTPSOnTheLogoService() {
        for issuer in BuiltInIssuers.all {
            guard let url = issuer.logoURL else { continue }
            XCTAssertEqual(url.scheme, "https", issuer.name)
            XCTAssertEqual(url.host, "logoapi.sh", issuer.name)
        }
    }
}
