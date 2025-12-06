//
//  OCRService.swift
//  ReadingCompanion
//
//  OCR service using Apple Vision framework for text extraction.
//

import Foundation
import Vision
import UIKit

/// Errors that can occur during OCR
enum OCRError: LocalizedError {
    case imageConversionFailed
    case noTextFound
    case processingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed:
            return "Failed to process the image."
        case .noTextFound:
            return "No text was detected in the image."
        case .processingFailed(let error):
            return "OCR processing failed: \(error.localizedDescription)"
        }
    }
}

/// Result of OCR processing
struct OCRResult {
    let text: String
    let confidence: Double

    var isHighConfidence: Bool {
        confidence >= 0.8
    }
}

/// Service for performing OCR on images
class OCRService {
    static let shared = OCRService()

    private init() {}

    /// Perform OCR on a UIImage
    func recognizeText(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: OCRError.processingFailed(error))
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation],
                      !observations.isEmpty else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }

                // Extract text and calculate average confidence
                var texts: [String] = []
                var totalConfidence: Float = 0

                for observation in observations {
                    if let topCandidate = observation.topCandidates(1).first {
                        texts.append(topCandidate.string)
                        totalConfidence += topCandidate.confidence
                    }
                }

                let averageConfidence = Double(totalConfidence) / Double(observations.count)
                let combinedText = texts.joined(separator: "\n")

                let result = OCRResult(
                    text: combinedText,
                    confidence: averageConfidence
                )

                continuation.resume(returning: result)
            }

            // Configure for accurate recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "en-GB"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.processingFailed(error))
            }
        }
    }
}
