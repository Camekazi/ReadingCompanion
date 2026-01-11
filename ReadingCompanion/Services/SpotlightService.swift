//
//  SpotlightService.swift
//  ReadingCompanion
//
//  Service for indexing books in Spotlight for quick iOS search.
//

import Foundation
import CoreSpotlight
import UniformTypeIdentifiers

/// Service for indexing books in iOS Spotlight Search
class SpotlightService {
    static let shared = SpotlightService()

    private let domainIdentifier = "com.readingcompanion.books"

    private init() {}

    // MARK: - Indexing

    /// Index a book for Spotlight search
    func indexBook(_ book: Book) {
        let attributeSet = CSSearchableItemAttributeSet(contentType: .text)

        // Basic info
        attributeSet.title = book.title
        attributeSet.displayName = book.title

        // Author as creator
        if let author = book.author {
            attributeSet.creator = author
            attributeSet.authorNames = [author]
        }

        // Progress description
        attributeSet.contentDescription = buildDescription(for: book)

        // Keywords for search
        var keywords = ["reading", "book", "library"]
        if let author = book.author {
            keywords.append(author)
        }
        attributeSet.keywords = keywords

        // Passage count
        if !book.passages.isEmpty {
            attributeSet.comment = "\(book.passages.count) saved passage\(book.passages.count == 1 ? "" : "s")"
        }

        let item = CSSearchableItem(
            uniqueIdentifier: book.id.uuidString,
            domainIdentifier: domainIdentifier,
            attributeSet: attributeSet
        )

        // Keep item for 30 days
        item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())

        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error = error {
                print("Spotlight indexing error: \(error.localizedDescription)")
            }
        }
    }

    /// Index multiple books at once
    func indexBooks(_ books: [Book]) {
        let items = books.map { book -> CSSearchableItem in
            let attributeSet = CSSearchableItemAttributeSet(contentType: .text)
            attributeSet.title = book.title
            attributeSet.displayName = book.title
            attributeSet.creator = book.author
            attributeSet.contentDescription = buildDescription(for: book)
            attributeSet.keywords = ["reading", "book", "library"]

            let item = CSSearchableItem(
                uniqueIdentifier: book.id.uuidString,
                domainIdentifier: domainIdentifier,
                attributeSet: attributeSet
            )
            item.expirationDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
            return item
        }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error = error {
                print("Spotlight batch indexing error: \(error.localizedDescription)")
            }
        }
    }

    /// Remove a book from Spotlight index
    func removeBook(_ book: Book) {
        CSSearchableIndex.default().deleteSearchableItems(
            withIdentifiers: [book.id.uuidString]
        ) { error in
            if let error = error {
                print("Spotlight removal error: \(error.localizedDescription)")
            }
        }
    }

    /// Remove all books from Spotlight index
    func removeAllBooks() {
        CSSearchableIndex.default().deleteSearchableItems(
            withDomainIdentifiers: [domainIdentifier]
        ) { error in
            if let error = error {
                print("Spotlight clear error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Helpers

    private func buildDescription(for book: Book) -> String {
        var parts: [String] = []

        // Progress
        if book.currentPage > 0 {
            if let total = book.totalPages, total > 0 {
                let percentage = Int((Double(book.currentPage) / Double(total)) * 100)
                parts.append("Page \(book.currentPage) of \(total) (\(percentage)%)")
            } else {
                parts.append("Page \(book.currentPage)")
            }
        } else {
            parts.append("Not started")
        }

        // Author
        if let author = book.author {
            parts.append("by \(author)")
        }

        // Passage count
        if !book.passages.isEmpty {
            parts.append("\(book.passages.count) passage\(book.passages.count == 1 ? "" : "s")")
        }

        return parts.joined(separator: " • ")
    }
}
