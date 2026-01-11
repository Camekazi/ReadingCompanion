//
//  EPUBService.swift
//  ReadingCompanion
//
//  Service for downloading book text from Internet Archive.
//  Uses plain text downloads (simpler than EPUB parsing).
//  Extracts chapter content for spoiler-free character queries.
//

import Foundation

/// Represents a chapter extracted from an EPUB
struct EPUBChapter: Codable, Identifiable {
    let id: String
    let title: String
    let content: String      // Plain text content
    let orderIndex: Int      // Position in reading order

    /// Approximate word count for progress estimation
    var wordCount: Int {
        content.split(separator: " ").count
    }
}

/// Result of parsing an EPUB file
struct EPUBContent: Codable {
    let title: String
    let author: String?
    let chapters: [EPUBChapter]
    let totalWordCount: Int

    /// Get all text up to and including a specific chapter
    func textUpToChapter(_ index: Int) -> String {
        chapters
            .filter { $0.orderIndex <= index }
            .sorted { $0.orderIndex < $1.orderIndex }
            .map { $0.content }
            .joined(separator: "\n\n")
    }

    /// Estimate which chapter corresponds to a page number
    /// Uses word count proportional distribution
    func chapterForPage(_ page: Int, totalPages: Int) -> Int {
        guard totalPages > 0, !chapters.isEmpty else { return 0 }
        let progress = Double(page) / Double(totalPages)
        let targetWords = Int(Double(totalWordCount) * progress)

        var cumulativeWords = 0
        for chapter in chapters.sorted(by: { $0.orderIndex < $1.orderIndex }) {
            cumulativeWords += chapter.wordCount
            if cumulativeWords >= targetWords {
                return chapter.orderIndex
            }
        }
        return chapters.count - 1
    }
}

/// Errors that can occur during EPUB processing
enum EPUBError: LocalizedError {
    case downloadFailed(String)
    case noTextVersion
    case invalidEPUB(String)
    case parsingFailed(String)
    case noContentFound

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .noTextVersion:
            return "This book doesn't have a downloadable text version on Internet Archive. You can still read it online or scan pages manually."
        case .invalidEPUB(let reason):
            return "Invalid EPUB: \(reason)"
        case .parsingFailed(let reason):
            return "Parsing failed: \(reason)"
        case .noContentFound:
            return "No readable content found in EPUB"
        }
    }
}

/// Service for downloading book text from Internet Archive
class EPUBService {
    static let shared = EPUBService()

    private init() {}

    /// Check if a text version is available for download
    /// - Parameter internetArchiveId: The IA identifier
    /// - Returns: true if text files are available
    func hasTextVersion(internetArchiveId: String) async -> Bool {
        let urlString = "https://archive.org/metadata/\(internetArchiveId)/files"
        guard let url = URL(string: urlString) else { return false }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let files = json["result"] as? [[String: Any]] else {
                return false
            }

            // Check for text file formats
            let textFormats = ["_djvu.txt", ".txt", "_text.txt"]
            for file in files {
                if let name = file["name"] as? String {
                    for format in textFormats {
                        if name.hasSuffix(format) {
                            return true
                        }
                    }
                }
            }
            return false
        } catch {
            return false
        }
    }

    /// Download book text from Internet Archive
    /// - Parameter internetArchiveId: The IA identifier (e.g., "prideandprejudice")
    /// - Returns: Parsed content with chapters
    func downloadAndParse(internetArchiveId: String) async throws -> EPUBContent {
        // Try different text formats available on Internet Archive
        let formats = [
            "\(internetArchiveId)_djvu.txt",     // OCR text (most common)
            "\(internetArchiveId).txt",           // Plain text
            "\(internetArchiveId)_text.txt"       // Alternate naming
        ]

        for format in formats {
            let urlString = "https://archive.org/download/\(internetArchiveId)/\(format)"
            guard let url = URL(string: urlString) else { continue }

            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200,
                      let text = String(data: data, encoding: .utf8) else {
                    continue
                }

                // Successfully downloaded text
                return parseTextIntoChapters(text, id: internetArchiveId)
            } catch {
                continue
            }
        }

        throw EPUBError.noTextVersion
    }

    /// Parse plain text into chapters using common patterns
    private func parseTextIntoChapters(_ text: String, id: String) -> EPUBContent {
        var chapters: [EPUBChapter] = []

        // Split by chapter markers (common patterns in public domain books)
        let chapterPatterns = [
            #"(?m)^CHAPTER\s+([IVXLCDM]+|\d+)"#,        // CHAPTER I, CHAPTER 1
            #"(?m)^Chapter\s+([IVXLCDM]+|\d+)"#,        // Chapter I, Chapter 1
            #"(?m)^BOOK\s+([IVXLCDM]+|\d+)"#,           // BOOK I
            #"(?m)^\*\*\*\s*$"#                          // *** dividers (Gutenberg style)
        ]

        var splitPoints: [(range: Range<String.Index>, title: String)] = []

        for pattern in chapterPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let range = Range(match.range, in: text) {
                        let title = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                        splitPoints.append((range: range, title: title))
                    }
                }
            }

            // If we found chapter markers, use them
            if !splitPoints.isEmpty { break }
        }

        // Sort split points by position
        splitPoints.sort { $0.range.lowerBound < $1.range.lowerBound }

        if splitPoints.isEmpty {
            // No chapter markers found - split by page breaks or create single chapter
            let segments = text.components(separatedBy: "\n\n\n")

            if segments.count > 5 {
                // Multiple segments - treat as chapters
                for (index, segment) in segments.enumerated() {
                    let content = segment.trimmingCharacters(in: .whitespacesAndNewlines)
                    if content.count > 100 { // Ignore very short segments
                        chapters.append(EPUBChapter(
                            id: "\(id)_\(index)",
                            title: "Section \(index + 1)",
                            content: content,
                            orderIndex: index
                        ))
                    }
                }
            } else {
                // Single large text - split by approximate word count (5000 words per chunk)
                let words = text.split(separator: " ")
                let chunkSize = 5000
                var index = 0

                for chunkStart in stride(from: 0, to: words.count, by: chunkSize) {
                    let chunkEnd = min(chunkStart + chunkSize, words.count)
                    let chunk = words[chunkStart..<chunkEnd].joined(separator: " ")

                    chapters.append(EPUBChapter(
                        id: "\(id)_\(index)",
                        title: "Part \(index + 1)",
                        content: chunk,
                        orderIndex: index
                    ))
                    index += 1
                }
            }
        } else {
            // Extract content between chapter markers
            for (index, splitPoint) in splitPoints.enumerated() {
                let contentStart = splitPoint.range.upperBound
                let contentEnd = (index + 1 < splitPoints.count)
                    ? splitPoints[index + 1].range.lowerBound
                    : text.endIndex

                let content = String(text[contentStart..<contentEnd])
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !content.isEmpty {
                    chapters.append(EPUBChapter(
                        id: "\(id)_\(index)",
                        title: splitPoint.title,
                        content: content,
                        orderIndex: index
                    ))
                }
            }
        }

        // Ensure we have at least one chapter
        if chapters.isEmpty {
            chapters.append(EPUBChapter(
                id: id,
                title: "Full Text",
                content: text,
                orderIndex: 0
            ))
        }

        let totalWords = chapters.reduce(0) { $0 + $1.wordCount }

        return EPUBContent(
            title: id.replacingOccurrences(of: "_", with: " ").capitalized,
            author: nil,
            chapters: chapters,
            totalWordCount: totalWords
        )
    }
}
