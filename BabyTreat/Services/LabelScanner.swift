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
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: ScanError.recognitionFailed(error.localizedDescription))
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                // Top to bottom: Vision's origin is bottom-left, so a larger
                // midY is higher up the label.
                let ordered = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                let lines = ordered.compactMap { $0.topCandidates(1).first?.string }
                if lines.isEmpty {
                    continuation.resume(throwing: ScanError.noTextFound)
                } else {
                    continuation.resume(returning: lines)
                }
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
}
