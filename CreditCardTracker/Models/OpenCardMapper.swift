import Foundation

enum IssuerCatalogError: Error, Equatable {
    /// The server answered with something other than a success code.
    case badStatus(Int)
    /// The file decoded, but it holds too few US cards to be the real list.
    case notEnoughCards(Int)
}

/// Turns opencard-db's `cards-all.json` into the app's list of `Issuer`s.
enum OpenCardMapper {
    /// The real file has hundreds of US cards. Fewer than this means we got something else (an error
    /// page, a changed file), so it is not used and not saved.
    static let minimumUSCards = 50

    /// The few fields we read from each card. Everything else in the file is ignored.
    private struct Record: Decodable {
        let id: String
        let name: String
        let country: String
        let issuer: String
        let issuerID: String

        enum CodingKeys: String, CodingKey {
            case id, name, country, issuer
            case issuerID = "issuer_id"
        }
    }

    /// Reads one entry of the list and never fails, so one broken card cannot throw away the other 500.
    private struct Lossy: Decodable {
        let record: Record?

        init(from decoder: Decoder) throws {
            record = try? Record(from: decoder)
        }
    }

    /// The US cards in the file, ready to show: the big issuers first, then the rest alphabetically,
    /// and each issuer's cards in alphabetical order.
    ///
    /// All US cards are kept: personal and business, active and discontinued. People still carry cards
    /// that are no longer sold.
    static func catalogCards(from data: Data, minimumCount: Int = minimumUSCards) throws -> [Issuer] {
        let records = try JSONDecoder().decode([Lossy].self, from: data).compactMap(\.record)

        var seenIDs = Set<String>()
        var entries: [(card: Issuer, issuerID: String)] = []
        for record in records where record.country == "us" {
            let id = record.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = record.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let issuer = record.issuer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !id.isEmpty, !name.isEmpty, !issuer.isEmpty, seenIDs.insert(id).inserted else { continue }

            let style = IssuerStyle.style(forCardID: id, issuerID: record.issuerID, issuerName: issuer)
            let card = Issuer(
                id: id,
                name: name,
                issuer: issuer,
                badgeCode: style.code,
                badgeColorHex: style.colorHex,
                logoDomain: style.logoDomain
            )
            entries.append((card, record.issuerID))
        }

        guard entries.count >= minimumCount else {
            throw IssuerCatalogError.notEnoughCards(entries.count)
        }

        entries.sort { lhs, rhs in
            let lhsPriority = IssuerStyle.priority(of: lhs.issuerID)
            let rhsPriority = IssuerStyle.priority(of: rhs.issuerID)
            if lhsPriority != rhsPriority { return lhsPriority < rhsPriority }

            let byIssuer = lhs.card.issuer.localizedStandardCompare(rhs.card.issuer)
            if byIssuer != .orderedSame { return byIssuer == .orderedAscending }

            let byName = lhs.card.name.localizedStandardCompare(rhs.card.name)
            if byName != .orderedSame { return byName == .orderedAscending }

            return lhs.card.id < rhs.card.id
        }
        return entries.map(\.card)
    }
}
