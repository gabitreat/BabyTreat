import Foundation

protocol OFFClient: Sendable {
    /// `.notFound` is a success. Only transport, decoding and rate limiting throw.
    func product(barcode: String) async throws -> OFFLookup
    func search(_ query: String) async throws -> [ProductSnapshot]
}

/// Live client. No force unwraps, no `try!`, and no `?? 0` on any nutrient.
final class LiveOFFClient: OFFClient {

    private let session: URLSession
    private let productBucket = TokenBucket(capacity: OFFEndpoint.Limit.productPerMinute)
    private let searchBucket = TokenBucket(capacity: OFFEndpoint.Limit.searchPerMinute)

    init(session: URLSession = .shared) {
        self.session = session
    }

    func product(barcode: String) async throws -> OFFLookup {
        let trimmed = barcode.trimmingCharacters(in: .whitespaces)
        guard OFFEndpoint.isValidBarcode(trimmed) else { throw OFFError.invalidBarcode }
        guard let url = OFFEndpoint.product(barcode: trimmed) else { throw OFFError.invalidBarcode }

        if let wait = await productBucket.take() { throw OFFError.rateLimited(retryAfter: wait) }

        let data = try await get(url)
        let response: OFFDTO.ProductResponse = try decode(data)

        // HTTP 200 with status 0 is the database saying "no such product".
        // Romanian coverage is thin, so this is a common path, not a failure.
        guard response.status == 1, let product = response.product else { return .notFound }
        return .found(OFFMapper.snapshot(from: product))
    }

    func search(_ query: String) async throws -> [ProductSnapshot] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = OFFEndpoint.search(trimmed) else { return [] }

        if let wait = await searchBucket.take() { throw OFFError.rateLimited(retryAfter: wait) }

        let data = try await get(url)
        let response: OFFDTO.SearchResponse = try decode(data)
        return (response.products ?? []).map(OFFMapper.snapshot(from:))
    }

    // MARK: - Transport

    private func get(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        // Mandatory. Anonymous clients get throttled or blocked outright.
        request.setValue(OFFEndpoint.userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw OFFError.network(underlying: error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { return data }

        if http.statusCode == 429 {
            let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
            throw OFFError.rateLimited(retryAfter: retryAfter)
        }
        guard (200...299).contains(http.statusCode) else {
            throw OFFError.http(statusCode: http.statusCode)
        }
        return data
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw OFFError.decoding(underlying: String(describing: error))
        }
    }
}
