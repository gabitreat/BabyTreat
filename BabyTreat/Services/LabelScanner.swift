import Foundation
import Vision
#if canImport(UIKit)
import UIKit
#endif

/// Reads text off a photograph of a nutrition label.
///
/// Uses Vision's on-device recogniser — nothing leaves the phone, which matters
/// for a photo that may have more than a label in frame.
enum LabelScanner {

    enum ScanError: LocalizedError {
        case noImageData
        case recognitionFailed(String)
        case noTextFound

        var errorDescription: String? {
            switch self {
            case .noImageData:
                "That image couldn't be read."
            case .recognitionFailed(let reason):
                "Couldn't read the label: \(reason)"
            case .noTextFound:
                "No text found in that photo. Try again with the label filling more of the frame."
            }
        }
    }

    /// Languages to try, most likely first. Romanian labels are usually printed
    /// alongside English, and the recogniser does better when told to expect both.
    static let languages = ["ro-RO", "en-US"]

    #if canImport(UIKit)
    /// Recognised lines, top to bottom.
    static func lines(in image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw ScanError.noImageData }
        return try await lines(in: cgImage)
    }
    #endif

    static func lines(in cgImage: CGImage) async throws -> [String] {
        let observations = try await recognise(in: cgImage)
        let lines = rows(from: observations)
        guard !lines.isEmpty else { throw ScanError.noTextFound }
        return lines
    }

    static func recognise(in cgImage: CGImage) async throws -> [VNRecognizedTextObservation] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScanError.recognitionFailed(error.localizedDescription))
                    return
                }
                continuation.resume(returning: request.results as? [VNRecognizedTextObservation] ?? [])
            }
            request.recognitionLevel = .accurate
            // Nutrition tables are numbers and short words; the language model
            // helps more than it hurts on the words and is harmless on digits.
            request.usesLanguageCorrection = true
            request.recognitionLanguages = languages

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: ScanError.recognitionFailed(error.localizedDescription))
            }
        }
    }

    /// Rebuilds table rows from the individual pieces Vision returns.
    ///
    /// A nutrition label is a table, and Vision hands back each cell separately:
    /// "Grăsimi" and "6,8 g" arrive as two observations, sometimes with the
    /// value listed *before* its own label. Sorting by height alone is not
    /// enough — cells sharing a row have to be grouped by their vertical
    /// position and then read left to right, or the value column ends up
    /// detached from the nutrient it belongs to.
    static func rows(from observations: [VNRecognizedTextObservation]) -> [String] {
        let pieces = observations.compactMap { observation -> (text: String, box: CGRect)? in
            guard let text = observation.topCandidates(1).first?.string else { return nil }
            return (text, observation.boundingBox)
        }
        guard !pieces.isEmpty else { return [] }

        // Rows count as the same when their centres sit within half a line
        // height of each other. Derived from the text itself so it holds for a
        // close-up photo and a distant one alike.
        let heights = pieces.map(\.box.height).sorted()
        let medianHeight = heights[heights.count / 2]
        let tolerance = max(medianHeight * 0.6, 0.005)

        var grouped: [[(text: String, box: CGRect)]] = []
        for piece in pieces.sorted(by: { $0.box.midY > $1.box.midY }) {
            if var last = grouped.last,
               let reference = last.first,
               abs(reference.box.midY - piece.box.midY) <= tolerance {
                last.append(piece)
                grouped[grouped.count - 1] = last
            } else {
                grouped.append([piece])
            }
        }

        return grouped.map { row in
            row.sorted { $0.box.minX < $1.box.minX }
                .map(\.text)
                .joined(separator: " ")
        }
    }
}
