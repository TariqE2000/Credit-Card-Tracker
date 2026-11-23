import Foundation

/// A bank or company that issues credit cards, e.g. "Chase" or "Navy Federal Credit Union". This is what the
/// user picks on "Pick your cards": one row per issuer, not one row per card.
///
/// The list is downloaded from opencard-db by `IssuerCatalogStore` and saved on the phone, which is why
/// this type is `Codable`. A short built-in list in `BuiltInIssuers` is used when it cannot load.
struct Issuer: Identifiable, Hashable, Codable {
    /// Stable ID from opencard-db, e.g. "chase" or "navy-federal".
    let id: String
    /// What the user sees, e.g. "American Express".
    let name: String
    /// Two or three letters shown in the colored badge, e.g. "CH".
    let badgeCode: String
    /// Badge color as 0xRRGGBB. Kept as a number so the model has no UI dependency.
    let badgeColorHex: UInt32
    /// The issuer's website, used to look up its logo, e.g. "capitalone.com". Nil when the logo service
    /// does not have the issuer; the colored badge is shown instead.
    var logoDomain: String? = nil
}

extension Issuer {
    /// An issuer with the badge letters, color and logo that `IssuerStyle` has for it.
    init(id: String, name: String) {
        let style = IssuerStyle.style(forIssuerID: id, issuerName: name)
        self.init(
            id: id,
            name: name,
            badgeCode: style.code,
            badgeColorHex: style.colorHex,
            logoDomain: style.logoDomain
        )
    }

    /// True when `query` is part of the issuer's name, or of its ID ("amex" finds American Express).
    /// Ignores case and accents. An empty query matches everything.
    func matches(_ query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return name.localizedStandardContains(trimmed)
            || id.replacingOccurrences(of: "-", with: " ").localizedStandardContains(trimmed)
    }
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
    /// Where to load this issuer's logo from. Nil when there is none to try.
    var logoURL: URL? {
        logoDomain.flatMap { LogoService.iconURL(forDomain: $0) }
    }
}

// MARK: - Banks that are not listed

/// A bank added with "My bank is not listed". The user types its name on the card form.
extension Issuer {
    static let customIDPrefix = "custom-"
    /// What an unnamed not-listed bank is called.
    static let defaultCustomName = "Other bank"

    var isCustom: Bool { id.hasPrefix(Self.customIDPrefix) }

    static func custom(
        id: String = Issuer.customIDPrefix + UUID().uuidString,
        name: String = ""
    ) -> Issuer {
        Issuer(id: id, name: name, badgeCode: "", badgeColorHex: 0x6B6B78)
    }

    /// The name to show. A not-listed bank left unnamed is shown as "Other bank".
    var displayName: String {
        guard isCustom else { return name }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.defaultCustomName : trimmed
    }
}
