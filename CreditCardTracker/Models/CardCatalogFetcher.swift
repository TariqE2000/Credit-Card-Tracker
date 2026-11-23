import Foundation

/// Downloads the card list. A protocol so tests can answer without using the network.
protocol CardCatalogFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

/// A plain HTTPS GET request to the CDN.
struct URLSessionCardFetcher: CardCatalogFetching {
    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw CardCatalogError.badStatus(http.statusCode)
        }
        return data
    }
}
