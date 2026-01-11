//
//  OpenLibraryService.swift
//  ReadingCompanion
//
//  Service for fetching book metadata from OpenLibrary API.
//

import Foundation

/// Represents a source where a book is freely available online
struct FreeBookSource: Identifiable {
    let id = UUID()
    let name: String
    let url: URL
    let type: SourceType

    enum SourceType: String {
        case openLibrary = "Open Library"
        case internetArchive = "Internet Archive"
        case projectGutenberg = "Project Gutenberg"
        case standardEbooks = "Standard Ebooks"
    }
}

/// Book metadata from OpenLibrary
struct BookMetadata {
    let title: String
    let author: String?
    let pageCount: Int?
    let publishYear: Int?
    let coverURL: URL?

    // Free book availability
    let hasFullText: Bool
    let internetArchiveIds: [String]
    let workKey: String?

    /// URLs where this book can be read for free
    var freeBookSources: [FreeBookSource] {
        var sources: [FreeBookSource] = []

        // Internet Archive sources
        for iaId in internetArchiveIds {
            if let url = URL(string: "https://archive.org/details/\(iaId)") {
                sources.append(FreeBookSource(
                    name: "Internet Archive",
                    url: url,
                    type: .internetArchive
                ))
            }
        }

        // Open Library reading page
        if hasFullText, let workKey = workKey,
           let url = URL(string: "https://openlibrary.org\(workKey)") {
            sources.append(FreeBookSource(
                name: "Open Library",
                url: url,
                type: .openLibrary
            ))
        }

        return sources
    }

    /// Whether any free version is available
    var hasFreeVersion: Bool {
        hasFullText || !internetArchiveIds.isEmpty
    }
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

    /// Search for FREE books only (has_fulltext=true filter)
    func searchFreeBooks(query: String, limit: Int = 20) async throws -> [BookMetadata] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }

        let urlString = "\(baseURL)/search.json?q=\(encodedQuery)&has_fulltext=true&limit=\(limit)"
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

        // Work key for linking to Open Library page
        let workKey = (json["works"] as? [[String: Any]])?.first?["key"] as? String

        // Internet Archive IDs (if available)
        let iaIds = json["ia_box_id"] as? [String] ?? []

        return BookMetadata(
            title: title,
            author: author,
            pageCount: pageCount,
            publishYear: nil,
            coverURL: coverURL,
            hasFullText: false,  // ISBN lookup doesn't include this
            internetArchiveIds: iaIds,
            workKey: workKey
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

            // Free book availability
            let hasFullText = doc["has_fulltext"] as? Bool ?? false
            let internetArchiveIds = doc["ia"] as? [String] ?? []
            let workKey = doc["key"] as? String

            return BookMetadata(
                title: title,
                author: author,
                pageCount: pageCount,
                publishYear: publishYear,
                coverURL: coverURL,
                hasFullText: hasFullText,
                internetArchiveIds: internetArchiveIds,
                workKey: workKey
            )
        }
    }

    /// Check for free versions from additional sources (Project Gutenberg, Standard Ebooks)
    func checkAdditionalFreeSources(title: String, author: String?) async -> [FreeBookSource] {
        var sources: [FreeBookSource] = []

        // Check Project Gutenberg
        if let gutenbergSource = await checkProjectGutenberg(title: title, author: author) {
            sources.append(gutenbergSource)
        }

        // Check Standard Ebooks
        if let standardSource = await checkStandardEbooks(title: title, author: author) {
            sources.append(standardSource)
        }

        return sources
    }

    /// Search Project Gutenberg for free book
    private func checkProjectGutenberg(title: String, author: String?) async -> FreeBookSource? {
        // Project Gutenberg search URL
        var searchTerms = title
        if let author = author {
            searchTerms += " \(author)"
        }

        guard let encoded = searchTerms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://www.gutenberg.org/ebooks/search/?query=\(encoded)") else {
            return nil
        }

        // For now, return a search link - full API integration would require parsing HTML
        // Project Gutenberg doesn't have a JSON API, so we provide a search link
        return FreeBookSource(
            name: "Search Project Gutenberg",
            url: searchURL,
            type: .projectGutenberg
        )
    }

    /// Search Standard Ebooks for free book
    private func checkStandardEbooks(title: String, author: String?) async -> FreeBookSource? {
        // Standard Ebooks uses a simple URL structure
        guard let encoded = title.lowercased()
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let searchURL = URL(string: "https://standardebooks.org/ebooks?query=\(encoded)") else {
            return nil
        }

        return FreeBookSource(
            name: "Search Standard Ebooks",
            url: searchURL,
            type: .standardEbooks
        )
    }
}
