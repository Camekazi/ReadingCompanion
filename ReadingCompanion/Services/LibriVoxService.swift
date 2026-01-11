//
//  LibriVoxService.swift
//  ReadingCompanion
//
//  Service for finding free audiobooks from LibriVox.
//  Level 1: Returns audiobook URL for linking out
//  Level 2 (future): Can return chapter list with MP3 URLs
//

import Foundation

/// Audiobook metadata from LibriVox
struct AudiobookMetadata {
    let id: String
    let title: String
    let author: String?
    let url: URL                    // LibriVox page URL
    let totalTime: String?          // e.g., "12:34:56"
    let language: String?

    // Level 2: Chapter data (for future expansion)
    let chapters: [AudiobookChapter]
}

/// Individual chapter in an audiobook (for Level 2 expansion)
struct AudiobookChapter: Identifiable {
    let id: String
    let title: String
    let duration: String?           // e.g., "45:23"
    let mp3URL: URL?
}

/// Service for fetching audiobook data from LibriVox
class LibriVoxService {
    static let shared = LibriVoxService()

    private let baseURL = "https://librivox.org/api/feed/audiobooks"

    private init() {}

    /// Search for audiobooks by title
    /// Returns the best matching audiobook if found
    func searchAudiobook(title: String, author: String? = nil) async throws -> AudiobookMetadata? {
        // Clean and encode the title for URL
        let cleanTitle = title
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let encodedTitle = cleanTitle.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)?title=^\(encodedTitle)&format=json") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            // LibriVox returns {"books": [...]} on success
            // or just {} when no results
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let books = json["books"] as? [[String: Any]],
                  !books.isEmpty else {
                return nil
            }

            // Find best match - prefer exact title match
            let bestMatch = findBestMatch(books: books, title: cleanTitle, author: author)

            return bestMatch.flatMap { parseAudiobook($0) }

        } catch {
            print("LibriVox search error: \(error)")
            return nil
        }
    }

    /// Find best matching book from results
    private func findBestMatch(books: [[String: Any]], title: String, author: String?) -> [String: Any]? {
        let lowercaseTitle = title.lowercased()

        // First pass: exact title match
        for book in books {
            if let bookTitle = book["title"] as? String,
               bookTitle.lowercased() == lowercaseTitle {
                return book
            }
        }

        // Second pass: title contains our search
        for book in books {
            if let bookTitle = book["title"] as? String,
               bookTitle.lowercased().contains(lowercaseTitle) {
                return book
            }
        }

        // Third pass: if author provided, match on author
        if let author = author?.lowercased() {
            for book in books {
                if let authors = book["authors"] as? [[String: Any]] {
                    for authorInfo in authors {
                        if let firstName = authorInfo["first_name"] as? String,
                           let lastName = authorInfo["last_name"] as? String {
                            let fullName = "\(firstName) \(lastName)".lowercased()
                            if fullName.contains(author) || author.contains(lastName.lowercased()) {
                                return book
                            }
                        }
                    }
                }
            }
        }

        // Fallback: return first result
        return books.first
    }

    /// Parse audiobook JSON into AudiobookMetadata
    private func parseAudiobook(_ json: [String: Any]) -> AudiobookMetadata? {
        guard let id = json["id"] as? String,
              let title = json["title"] as? String,
              let urlString = json["url_librivox"] as? String,
              let url = URL(string: urlString) else {
            return nil
        }

        // Extract author name
        var author: String?
        if let authors = json["authors"] as? [[String: Any]],
           let firstAuthor = authors.first {
            let firstName = firstAuthor["first_name"] as? String ?? ""
            let lastName = firstAuthor["last_name"] as? String ?? ""
            author = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
            if author?.isEmpty == true { author = nil }
        }

        let totalTime = json["totaltimesecs"] as? Int
        let totalTimeFormatted = totalTime.map { formatDuration($0) }

        let language = json["language"] as? String

        // Level 2: Parse chapters if available (for future expansion)
        var chapters: [AudiobookChapter] = []
        if let sections = json["sections"] as? [[String: Any]] {
            chapters = sections.compactMap { section in
                guard let sectionId = section["id"] as? String,
                      let sectionTitle = section["title"] as? String else {
                    return nil
                }

                let duration = (section["playtime"] as? String)
                let mp3URLString = section["listen_url"] as? String
                let mp3URL = mp3URLString.flatMap { URL(string: $0) }

                return AudiobookChapter(
                    id: sectionId,
                    title: sectionTitle,
                    duration: duration,
                    mp3URL: mp3URL
                )
            }
        }

        return AudiobookMetadata(
            id: id,
            title: title,
            author: author,
            url: url,
            totalTime: totalTimeFormatted,
            language: language,
            chapters: chapters
        )
    }

    /// Format seconds into "HH:MM:SS" or "MM:SS"
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
}
