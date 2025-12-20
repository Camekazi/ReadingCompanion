//
//  OpenLibraryService.swift
//  ReadingCompanion
//
//  Service for fetching book metadata from OpenLibrary API.
//

import Foundation

/// Book metadata from OpenLibrary
struct BookMetadata {
    let title: String
    let author: String?
    let pageCount: Int?
    let publishYear: Int?
    let coverURL: URL?
}

/// Service for fetching book data from OpenLibrary
class OpenLibraryService {
    static let shared = OpenLibraryService()

    private let baseURL = "https://openlibrary.org"

    private init() {}

    /// Fetch book metadata by ISBN
    func fetchBook(isbn: String) async throws -> BookMetadata? {
        let cleanISBN = isbn.replacingOccurrences(of: "-", with: "")

        // Try ISBN API first
        let urlString = "\(baseURL)/isbn/\(cleanISBN).json"
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return parseBookData(json, isbn: cleanISBN)
        } catch {
            print("OpenLibrary fetch error: \(error)")
            return nil
        }
    }

    /// Search for books by title and author
    func searchBooks(title: String, author: String? = nil) async throws -> [BookMetadata] {
        var query = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? title
        if let author = author {
            query += "+\(author.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? author)"
        }

        let urlString = "\(baseURL)/search.json?q=\(query)&limit=5"
        guard let url = URL(string: urlString) else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return []
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            return parseSearchResults(json)
        } catch {
            print("OpenLibrary search error: \(error)")
            return []
        }
    }

    /// Parse book data from ISBN API response (internal for testing)
    func parseBookData(_ json: [String: Any]?, isbn: String) -> BookMetadata? {
        guard let json = json else { return nil }

        let title = json["title"] as? String ?? "Unknown"

        // Get author from author key
        var author: String?
        if let authors = json["authors"] as? [[String: Any]],
           let firstAuthor = authors.first,
           let authorKey = firstAuthor["key"] as? String {
            // Would need another API call to get author name
            // For simplicity, we'll skip this for now
            author = nil
        }

        let pageCount = json["number_of_pages"] as? Int

        // Cover URL
        var coverURL: URL?
        if let covers = json["covers"] as? [Int], let coverId = covers.first {
            coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
        } else {
            // Try ISBN-based cover
            coverURL = URL(string: "https://covers.openlibrary.org/b/isbn/\(isbn)-M.jpg")
        }

        return BookMetadata(
            title: title,
            author: author,
            pageCount: pageCount,
            publishYear: nil,
            coverURL: coverURL
        )
    }

    /// Parse search results from search API response (internal for testing)
    func parseSearchResults(_ json: [String: Any]?) -> [BookMetadata] {
        guard let json = json,
              let docs = json["docs"] as? [[String: Any]] else {
            return []
        }

        return docs.compactMap { doc in
            guard let title = doc["title"] as? String else { return nil }

            let author = (doc["author_name"] as? [String])?.first
            let pageCount = doc["number_of_pages_median"] as? Int
            let publishYear = doc["first_publish_year"] as? Int

            var coverURL: URL?
            if let coverId = doc["cover_i"] as? Int {
                coverURL = URL(string: "https://covers.openlibrary.org/b/id/\(coverId)-M.jpg")
            }

            return BookMetadata(
                title: title,
                author: author,
                pageCount: pageCount,
                publishYear: publishYear,
                coverURL: coverURL
            )
        }
    }
}
