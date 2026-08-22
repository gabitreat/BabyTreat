import Foundation

/// URL construction for Open Food Facts.
enum OFFEndpoint {

    /// The Romanian subdomain queries the same global database — it changes
    /// language and country ranking, not the dataset.
    static let host = "https://ro.openfoodfacts.org"

    /// **Mandatory on every request.** Open Food Facts throttles or blocks
    /// anonymous clients, so this is not optional politeness.
    ///
    /// The contact address identifies this app to a third party on every
    /// lookup. Change it here and nowhere else.
    static let contactEmail = "gabibittreat@gmail.com"
    static let userAgent = "BabyTreat/1.0 (iOS) - \(contactEmail)"

    /// Only what the mapper reads. Asking for the whole document wastes
    /// bandwidth on a product record that can run to hundreds of fields.
    static let productFields = [
        "code", "product_name", "product_name_ro", "generic_name_ro", "brands", "quantity",
        "categories_tags", "allergens_tags", "traces_tags", "ingredients_text_ro",
        "nutriments", "nutriscore_grade", "nova_group",
        "image_front_small_url", "image_front_url",
    ]

    /// Digits only, 8–14 long. EAN-8 through GTIN-14.
    static func isValidBarcode(_ barcode: String) -> Bool {
        let trimmed = barcode.trimmingCharacters(in: .whitespaces)
        return trimmed.count >= 8 && trimmed.count <= 14 && trimmed.allSatisfy(\.isNumber)
    }

    static func product(barcode: String) -> URL? {
        var components = URLComponents(string: "\(host)/api/v2/product/\(barcode).json")
        components?.queryItems = [
            URLQueryItem(name: "lc", value: "ro"),
            URLQueryItem(name: "cc", value: "ro"),
            URLQueryItem(name: "fields", value: productFields.joined(separator: ",")),
        ]
        return components?.url
    }

    static func search(_ query: String, pageSize: Int = 20) -> URL? {
        var components = URLComponents(string: "\(host)/cgi/search.pl")
        components?.queryItems = [
            URLQueryItem(name: "search_terms", value: query),
            URLQueryItem(name: "lc", value: "ro"),
            URLQueryItem(name: "cc", value: "ro"),
            URLQueryItem(name: "json", value: "1"),
            URLQueryItem(name: "page_size", value: String(pageSize)),
        ]
        return components?.url
    }

    /// Server-enforced, per minute.
    enum Limit {
        static let productPerMinute = 100
        static let searchPerMinute = 10
    }
}

/// Fixed-window token bucket, one per endpoint class.
///
/// An actor because two lookups can be in flight from different tasks and the
/// counter must not be shared unsafely. Deliberately does **not** retry on
/// exhaustion: it reports how long to wait and lets the caller decide, because
/// an automatic retry loop against a rate limiter makes the problem worse.
actor TokenBucket {
    private let capacity: Int
    private let window: TimeInterval
    private var timestamps: [Date] = []

    init(capacity: Int, window: TimeInterval = 60) {
        self.capacity = capacity
        self.window = window
    }

    /// Returns `nil` when a request may proceed, or the seconds to wait.
    func take(now: Date = .now) -> TimeInterval? {
        timestamps.removeAll { now.timeIntervalSince($0) >= window }
        guard timestamps.count >= capacity else {
            timestamps.append(now)
            return nil
        }
        guard let oldest = timestamps.first else { return window }
        return max(0, window - now.timeIntervalSince(oldest))
    }
}
