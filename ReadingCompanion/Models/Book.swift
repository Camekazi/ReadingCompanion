//
//  Book.swift
//  ReadingCompanion
//
//  SwiftData model for tracking books in the library.
//

import Foundation
import SwiftData

@Model
final class Book {
    var id: UUID
    var title: String
    var author: String?
    var isbn: String?
    var currentPage: Int
    var totalPages: Int?
    var dateAdded: Date
    var dateLastRead: Date?

    @Relationship(deleteRule: .cascade, inverse: \Passage.book)
    var passages: [Passage]

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        isbn: String? = nil,
        currentPage: Int = 0,
        totalPages: Int? = nil,
        dateAdded: Date = Date(),
        passages: [Passage] = []
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isbn = isbn
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.dateAdded = dateAdded
        self.passages = passages
    }

    /// Get passages up to the current reading position (for spoiler-free queries)
    var passagesUpToCurrentPage: [Passage] {
        passages
            .filter { ($0.pageNumber ?? 0) <= currentPage }
            .sorted { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }
    }

    /// Formatted display of reading progress
    var progressDescription: String {
        if let total = totalPages, total > 0 {
            let percent = Int((Double(currentPage) / Double(total)) * 100)
            return "Page \(currentPage) of \(total) (\(percent)%)"
        }
        return currentPage > 0 ? "Page \(currentPage)" : "Not started"
    }
}
