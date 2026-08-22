import Foundation
import SwiftData

/// Cache-first product lookup: local store → network → `.notFound`.
///
/// The only place in this layer that touches SwiftData. Kept apart from
/// `OFFClient` so the client stays a pure networking type.
@MainActor
struct FoodProductStore {
    let context: ModelContext
    let client: OFFClient

    init(context: ModelContext, client: OFFClient = LiveOFFClient()) {
        self.context = context
        self.client = client
    }

    enum Result: Equatable {
        case cached(FoodProduct)
        case fetched(FoodProduct)
        /// Refetch failed and a stale copy was served instead. Old data beats
        /// no data, but the caller is told which it got.
        case stale(FoodProduct, OFFError)
        case notFound
    }

    func lookup(barcode: String) async -> Result {
        let trimmed = barcode.trimmingCharacters(in: .whitespaces)
        let existing = cached(barcode: trimmed)

        if let existing, !existing.isStale() { return .cached(existing) }

        do {
            switch try await client.product(barcode: trimmed) {
            case .found(let snapshot):
                if let existing {
                    existing.update(from: snapshot)
                    try? context.save()
                    return .fetched(existing)
                }
                let product = FoodProduct(snapshot: snapshot)
                context.insert(product)
                try? context.save()
                return .fetched(product)

            case .notFound:
                // A stale cached copy is still better than nothing, even if the
                // product has since been removed from the database.
                if let existing { return .cached(existing) }
                return .notFound
            }
        } catch let error as OFFError {
            if let existing { return .stale(existing, error) }
            return .notFound
        } catch {
            if let existing { return .stale(existing, .network(underlying: error.localizedDescription)) }
            return .notFound
        }
    }

    func cached(barcode: String) -> FoodProduct? {
        var descriptor = FetchDescriptor<FoodProduct>(
            predicate: #Predicate { $0.barcode == barcode }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
