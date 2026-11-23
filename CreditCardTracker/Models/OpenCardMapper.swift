import Foundation

enum IssuerCatalogError: Error, Equatable {
    /// The server answered with something other than a success code.
    case badStatus(Int)
    /// The files decoded, but they hold too few US issuers to be the real list.
    case notEnoughIssuers(Int)
}

/// Turns opencard-db's issuer files into the app's list of `Issuer`s.
enum OpenCardMapper {
    /// The real list has about 50 US issuers. Fewer than this means we got something else (an error
    /// page, a changed file), so it is not used and not saved.
    static let minimumUSIssuers = 20

    /// The two fields we read from each registry entry. Everything else in the file is ignored.
    private struct Entry: Decodable {
        let id: String
        let name: String
    }

    private struct Registry: Decodable {
        let issuers: [Lossy]
    }

    /// Reads one entry and never fails, so one broken entry cannot throw away the other 60.
    private struct Lossy: Decodable {
        let entry: Entry?

        init(from decoder: Decoder) throws {
            entry = try? Entry(from: decoder)
        }
    }

    /// The issuers that have at least one US card, ready to show: the big issuers first, then the rest
    /// alphabetically.
    ///
    /// - `registryData` is `data/issuers.json`: every issuer, with its name.
    /// - `indexData` is `exports/index-issuer.json`: each issuer's card IDs. An issuer is American when
    ///   one of its card IDs starts with "us-".
    ///
    /// Every US issuer is kept, including banks that only issue cards for other companies and issuers
    /// whose cards are no longer sold. People still carry those cards.
    static func issuers(
        registryData: Data,
        indexData: Data,
        minimumCount: Int = minimumUSIssuers
    ) throws -> [Issuer] {
        let registry = try JSONDecoder().decode(Registry.self, from: registryData).issuers.compactMap(\.entry)
        let cardIDsByIssuer = try JSONDecoder().decode([String: [String]].self, from: indexData)
        let usIssuerIDs = Set(cardIDsByIssuer.filter { entry in
            entry.value.contains { $0.hasPrefix("us-") }
        }.keys)

        var seenIDs = Set<String>()
        var issuers: [Issuer] = []
        for entry in registry where usIssuerIDs.contains(entry.id) {
            let id = entry.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let registryName = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !registryName.isEmpty, seenIDs.insert(id).inserted else { continue }

            let name = IssuerStyle.displayName(forIssuerID: id, registryName: registryName)
            issuers.append(Issuer(id: id, name: name))
        }

        guard issuers.count >= minimumCount else {
            throw IssuerCatalogError.notEnoughIssuers(issuers.count)
        }

        return issuers.sorted { lhs, rhs in
            let lhsPriority = IssuerStyle.priority(of: lhs.id)
            let rhsPriority = IssuerStyle.priority(of: rhs.id)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }

            let byName = lhs.name.localizedStandardCompare(rhs.name)
            if byName != .orderedSame { return byName == .orderedAscending }

            return lhs.id < rhs.id
        }
    }
}
