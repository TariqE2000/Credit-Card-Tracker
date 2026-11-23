import Foundation

/// A card the user can pick during onboarding, e.g. "Chase Sapphire Preferred".
///
/// The full list is downloaded from opencard-db by `IssuerCatalogStore` and saved on the phone, which is
/// why this type is `Codable`. A short built-in list in `BuiltInIssuers` is used when it cannot load.
struct Issuer: Identifiable, Hashable, Codable {
    /// Stable ID from opencard-db, e.g. "us-chase-sapphire-preferred".
    let id: String
    let name: String
    let issuer: String
    /// Two or three letters shown in the colored badge, e.g. "CH".
    let badgeCode: String
    /// Badge color as 0xRRGGBB. Kept as a number so the model has no UI dependency.
    let badgeColorHex: UInt32
    /// The issuer's website, used to look up its logo, e.g. "capitalone.com". Nil when the logo service
    /// does not have the issuer; the colored badge is shown instead.
    var logoDomain: String? = nil
}

// MARK: - Issuer logos

/// Issuer logos come from LogoAPI.sh: free, no key, no sign-up and no attribution.
enum LogoService {
    /// The square icon for a website, as a PNG (an image view on iOS cannot draw SVG).
    /// `fallback=404` makes a missing logo come back as an error, so the app shows its own colored
    /// badge instead of a stand-in picture. `size` snaps to 128, 256, 512 or 1024.
    static func iconURL(forDomain domain: String, size: Int = 256) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "logoapi.sh"
        components.path = "/icon/\(domain).png"
        components.queryItems = [
            URLQueryItem(name: "size", value: String(size)),
            URLQueryItem(name: "fallback", value: "404"),
        ]
        return components.url
    }
}

extension LogoService {
    /// Debug builds only: when a logo does not load, ask the server again and print what it answered,
    /// so the reason shows in the Xcode console (lines start with "[Logo]").
    static func reportFailure(for url: URL, error: Error) {
        #if DEBUG
        print("[Logo] could not load \(url.absoluteString): \(error.localizedDescription)")
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse {
                    let type = http.value(forHTTPHeaderField: "Content-Type") ?? "no content type"
                    print("[Logo] the server answered \(http.statusCode), \(type), \(data.count) bytes")
                }
            } catch {
                print("[Logo] network error: \(error.localizedDescription)")
            }
        }
        #endif
    }
}

extension Issuer {
    /// Where to load this card's issuer logo from. Nil when there is none to try.
    var logoURL: URL? {
        logoDomain.flatMap { LogoService.iconURL(forDomain: $0) }
    }
}

// MARK: - Cards that are not listed

/// A card the user added with "My card is not listed". The user types its name on the card form,
/// and the first word of that name is shown where a catalog card shows its issuer.
extension Issuer {
    static let customIDPrefix = "custom-"
    /// What an unnamed not-listed card is called.
    static let defaultCustomName = "Other card"

    var isCustom: Bool { id.hasPrefix(Self.customIDPrefix) }

    static func custom(
        id: String = Issuer.customIDPrefix + UUID().uuidString,
        name: String = ""
    ) -> Issuer {
        Issuer(id: id, name: name, issuer: firstWord(of: name) ?? "Not listed", badgeCode: "", badgeColorHex: 0x6B6B78)
    }

    /// "Navy Federal" gives "Navy". Nil when there is no word yet.
    static func firstWord(of name: String) -> String? {
        name.split(whereSeparator: \.isWhitespace).first.map(String.init)
    }

    /// The name to show. A not-listed card left unnamed is shown as "Other card".
    var displayName: String {
        guard isCustom else { return name }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultCustomName : trimmed
    }
}
