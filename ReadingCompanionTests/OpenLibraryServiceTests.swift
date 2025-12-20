//
//  OpenLibraryServiceTests.swift
//  ReadingCompanionTests
//
//  Tests for OpenLibraryService JSON parsing.
//

import Testing
import Foundation
@testable import ReadingCompanion

@Suite("OpenLibrary Service Tests")
struct OpenLibraryServiceTests {

    // MARK: - Test Fixtures

    /// Sample ISBN API response fixture
    private func sampleISBNResponse() -> [String: Any] {
        return [
            "title": "The Great Gatsby",
            "number_of_pages": 180,
            "covers": [12345, 67890],
            "authors": [
                ["key": "/authors/OL123456A"]
            ]
        ]
    }

    /// Sample search API response fixture
    private func sampleSearchResponse() -> [String: Any] {
        return [
            "numFound": 2,
            "docs": [
                [
                    "title": "1984",
                    "author_name": ["George Orwell"],
                    "number_of_pages_median": 328,
                    "first_publish_year": 1949,
                    "cover_i": 11111
                ],
                [
                    "title": "Animal Farm",
                    "author_name": ["George Orwell"],
                    "number_of_pages_median": 112,
                    "first_publish_year": 1945,
                    "cover_i": 22222
                ]
            ]
        ]
    }

    // MARK: - parseBookData Tests

    @Test("Parse book data extracts title")
    func parseBookData_extractsTitle() {
        // Given: ISBN response with title
        let json = sampleISBNResponse()
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let result = service.parseBookData(json, isbn: "9780743273565")

        // Then: Title is extracted
        #expect(result?.title == "The Great Gatsby")
    }

    @Test("Parse book data extracts page count")
    func parseBookData_extractsPageCount() {
        // Given: ISBN response with page count
        let json = sampleISBNResponse()
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let result = service.parseBookData(json, isbn: "9780743273565")

        // Then: Page count is extracted
        #expect(result?.pageCount == 180)
    }

    @Test("Parse book data builds cover URL from cover ID")
    func parseBookData_buildsCoverURLFromId() {
        // Given: ISBN response with cover IDs
        let json = sampleISBNResponse()
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let result = service.parseBookData(json, isbn: "9780743273565")

        // Then: Cover URL uses first cover ID
        #expect(result?.coverURL?.absoluteString == "https://covers.openlibrary.org/b/id/12345-M.jpg")
    }

    @Test("Parse book data falls back to ISBN cover URL")
    func parseBookData_fallsBackToISBNCoverURL() {
        // Given: ISBN response without covers
        let json: [String: Any] = [
            "title": "No Cover Book"
        ]
        let service = OpenLibraryService.shared
        let isbn = "1234567890"

        // When: Parsing the response
        let result = service.parseBookData(json, isbn: isbn)

        // Then: Cover URL uses ISBN
        #expect(result?.coverURL?.absoluteString == "https://covers.openlibrary.org/b/isbn/1234567890-M.jpg")
    }

    @Test("Parse book data handles missing fields")
    func parseBookData_handlesMissingFields() {
        // Given: Minimal ISBN response
        let json: [String: Any] = [
            "title": "Minimal Book"
        ]
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let result = service.parseBookData(json, isbn: "0000000000")

        // Then: Result is valid with nil optionals
        #expect(result != nil)
        #expect(result?.title == "Minimal Book")
        #expect(result?.author == nil)  // Author requires extra API call
        #expect(result?.pageCount == nil)
    }

    @Test("Parse book data defaults to 'Unknown' title")
    func parseBookData_defaultsToUnknownTitle() {
        // Given: Response with no title
        let json: [String: Any] = [
            "number_of_pages": 100
        ]
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let result = service.parseBookData(json, isbn: "0000000000")

        // Then: Title defaults to "Unknown"
        #expect(result?.title == "Unknown")
    }

    @Test("Parse book data returns nil for nil json")
    func parseBookData_returnsNilForNilJson() {
        // Given: Nil JSON
        let service = OpenLibraryService.shared

        // When: Parsing nil
        let result = service.parseBookData(nil, isbn: "0000000000")

        // Then: Returns nil
        #expect(result == nil)
    }

    // MARK: - parseSearchResults Tests

    @Test("Parse search results returns list")
    func parseSearchResults_returnsList() {
        // Given: Search response with docs
        let json = sampleSearchResponse()
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let results = service.parseSearchResults(json)

        // Then: All docs are parsed
        #expect(results.count == 2)
    }

    @Test("Parse search results extracts all fields")
    func parseSearchResults_extractsAllFields() {
        // Given: Search response
        let json = sampleSearchResponse()
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let results = service.parseSearchResults(json)

        // Then: First result has all fields
        let first = results.first
        #expect(first?.title == "1984")
        #expect(first?.author == "George Orwell")
        #expect(first?.pageCount == 328)
        #expect(first?.publishYear == 1949)
        #expect(first?.coverURL?.absoluteString == "https://covers.openlibrary.org/b/id/11111-M.jpg")
    }

    @Test("Parse search results handles empty docs")
    func parseSearchResults_handlesEmptyResults() {
        // Given: Search response with no docs
        let json: [String: Any] = [
            "numFound": 0,
            "docs": []
        ]
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let results = service.parseSearchResults(json)

        // Then: Empty array returned
        #expect(results.isEmpty)
    }

    @Test("Parse search results handles nil json")
    func parseSearchResults_handlesNilJson() {
        // Given: Nil JSON
        let service = OpenLibraryService.shared

        // When: Parsing nil
        let results = service.parseSearchResults(nil)

        // Then: Empty array returned
        #expect(results.isEmpty)
    }

    @Test("Parse search results skips docs without title")
    func parseSearchResults_skipsDocsWithoutTitle() {
        // Given: Response with invalid doc
        let json: [String: Any] = [
            "docs": [
                ["author_name": ["No Title Author"]],  // Missing title
                ["title": "Valid Book"]
            ]
        ]
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let results = service.parseSearchResults(json)

        // Then: Only valid doc is included
        #expect(results.count == 1)
        #expect(results.first?.title == "Valid Book")
    }

    @Test("Parse search results handles missing optional fields")
    func parseSearchResults_handlesMissingOptionalFields() {
        // Given: Doc with only title
        let json: [String: Any] = [
            "docs": [
                ["title": "Title Only"]
            ]
        ]
        let service = OpenLibraryService.shared

        // When: Parsing the response
        let results = service.parseSearchResults(json)

        // Then: Optional fields are nil
        #expect(results.count == 1)
        #expect(results.first?.title == "Title Only")
        #expect(results.first?.author == nil)
        #expect(results.first?.pageCount == nil)
        #expect(results.first?.publishYear == nil)
        #expect(results.first?.coverURL == nil)
    }
}
