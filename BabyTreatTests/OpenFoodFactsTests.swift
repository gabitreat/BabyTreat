import XCTest
@testable import BabyTreat

/// Stubs the transport so every test runs through the real client, mapper and
/// decoder without ever touching the network.
final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var payload: (status: Int, body: String) = (200, "{}")

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let (status, body) = StubURLProtocol.payload
        let response = HTTPURLResponse(
            url: request.url ?? URL(fileURLWithPath: "/"),
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class OpenFoodFactsTests: XCTestCase {

    private func makeClient() -> LiveOFFClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return LiveOFFClient(session: URLSession(configuration: config))
    }

    private func lookup(_ body: String, status: Int = 200, barcode: String = "5941234567890") async throws -> OFFLookup {
        StubURLProtocol.payload = (status, body)
        return try await makeClient().product(barcode: barcode)
    }

    /// 1. A well-populated product decodes with all macros.
    func testFullProductDecodesAllMacros() async throws {
        let result = try await lookup(OFFFixtures.fullProduct)
        let product = try XCTUnwrap(result.product)

        XCTAssertEqual(product.name, "Iaurt grecesc 10%")
        XCTAssertEqual(product.brand, "Olympus")
        XCTAssertEqual(product.nutrition.kcal, 116)
        XCTAssertEqual(product.nutrition.protein, 5.6)
        XCTAssertEqual(product.nutrition.carbs, 3.2)
        XCTAssertEqual(product.nutrition.sugars, 3.2)
        XCTAssertEqual(product.nutrition.fat, 10)
        XCTAssertEqual(product.nutrition.saturatedFat, 6.5)
        XCTAssertEqual(product.nutrition.fiber, 0)
        XCTAssertEqual(product.nutrition.salt, 0.1)
        XCTAssertEqual(product.nutrition.sodium, 0.04)
        XCTAssertEqual(product.nutrition.basis, .raw)
        XCTAssertEqual(product.nutrition.per100, .grams)
        XCTAssertFalse(product.nutrition.energyWasDerived)

        // Free text, kept for display only — never used for arithmetic.
        XCTAssertEqual(product.servingSizeDisplay, "150 g")
    }

    /// 2. kJ only: kcal is derived and flagged as derived.
    func testKilojoulesDeriveKcalAndSetFlag() async throws {
        let result = try await lookup(OFFFixtures.kilojoulesOnly, barcode: "1111111111111")
        let product = try XCTUnwrap(result.product)

        let expected = 3700 / NutritionFacts.kilojoulesPerKcal
        XCTAssertEqual(try XCTUnwrap(product.nutrition.kcal), expected, accuracy: 0.001)
        XCTAssertTrue(product.nutrition.energyWasDerived)

        // "91,6" — a comma decimal, and a number arriving as a string.
        XCTAssertEqual(product.nutrition.fat, 91.6)
        // 500 ml on the pack, so the figures are per 100 ml.
        XCTAssertEqual(product.nutrition.per100, .millilitres)
    }

    /// 3. `status: 0` is a normal answer, not an error.
    func testNotFoundIsSuccessNotThrow() async throws {
        let result = try await lookup(OFFFixtures.notFound, barcode: "5949000000000")
        XCTAssertEqual(result, .notFound)
    }

    /// 4. A missing nutrient is nil, never zero.
    func testMissingProteinIsNilNotZero() async throws {
        let result = try await lookup(OFFFixtures.missingProtein, barcode: "2222222222222")
        let product = try XCTUnwrap(result.product)

        XCTAssertNil(product.nutrition.protein)
        // …while a genuine zero survives as zero. The two must not collapse.
        XCTAssertEqual(product.nutrition.kcal, 0)
        XCTAssertEqual(product.nutrition.fat, 0)
    }

    /// 5. Language prefixes are stripped from allergen and trace tags.
    func testAllergenTagsHavePrefixStripped() async throws {
        let result = try await lookup(OFFFixtures.fullProduct)
        let product = try XCTUnwrap(result.product)

        XCTAssertEqual(product.allergenTags, ["milk"])
        XCTAssertEqual(product.traceTags, ["nuts"])
        XCTAssertEqual(product.categoryTags, ["dairies", "yogurts"])
    }

    /// 6. The name fallback treats "" as missing, not just nil.
    func testDisplayNameFallsBackPastEmptyString() async throws {
        let result = try await lookup(OFFFixtures.missingProtein, barcode: "2222222222222")
        let product = try XCTUnwrap(result.product)

        // product_name_ro is "", so the chain must reach product_name.
        XCTAssertEqual(product.name, "Apa minerala")
    }

    // MARK: - Supporting behaviour

    func testNonSuccessStatusThrowsHTTP() async {
        StubURLProtocol.payload = (503, "{}")
        do {
            _ = try await makeClient().product(barcode: "5941234567890")
            XCTFail("expected an HTTP error")
        } catch let error as OFFError {
            XCTAssertEqual(error, .http(statusCode: 503))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testInvalidBarcodeRejectedBeforeAnyRequest() async {
        do {
            _ = try await makeClient().product(barcode: "abc")
            XCTFail("expected invalidBarcode")
        } catch let error as OFFError {
            XCTAssertEqual(error, .invalidBarcode)
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testTokenBucketReportsWaitWhenExhausted() async {
        let bucket = TokenBucket(capacity: 2, window: 60)
        let now = Date(timeIntervalSince1970: 1_000_000)
        // Bound outside the assertion: XCTAssert's autoclosure cannot await.
        let first = await bucket.take(now: now)
        let second = await bucket.take(now: now)
        let wait = await bucket.take(now: now)
        XCTAssertNil(first)
        XCTAssertNil(second)
        XCTAssertNotNil(wait, "third call inside the window must be refused")
    }

    func testScalingAnUnknownStaysUnknown() {
        let facts = NutritionFacts(kcal: 200, protein: nil)
        let scaled = facts.scaled(to: 50)
        XCTAssertEqual(scaled.kcal, 100)
        XCTAssertNil(scaled.protein)
    }
}
