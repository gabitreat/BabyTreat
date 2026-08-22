import Foundation

/// Failures the Open Food Facts client can report.
///
/// `notFound` is deliberately **not** here. A product missing from the database
/// is an expected answer, modelled as `OFFLookup.notFound`, so the caller can
/// fall through to manual entry without treating it as something going wrong.
enum OFFError: Error, Equatable {
    case http(statusCode: Int)
    case rateLimited(retryAfter: TimeInterval?)
    case decoding(underlying: String)
    case network(underlying: String)
    case invalidBarcode

    var userMessage: String {
        switch self {
        case .http(let code):
            "The food database answered with an error (\(code)). Try again, or enter it by hand."
        case .rateLimited(let retryAfter):
            retryAfter.map { "Too many lookups. Try again in \(Int($0))s." }
                ?? "Too many lookups just now. Try again shortly."
        case .decoding:
            "That product's data could not be read. Enter it by hand."
        case .network:
            "No connection to the food database."
        case .invalidBarcode:
            "That barcode doesn't look right."
        }
    }
}
