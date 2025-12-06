//
//  Passage.swift
//  ReadingCompanion
//
//  SwiftData model for storing scanned/entered passages.
//

import Foundation
import SwiftData

@Model
final class Passage {
    var id: UUID
    var text: String
    var pageNumber: Int?
    var aiSummary: String?
    var userNotes: String?
    var dateCreated: Date

    var book: Book?

    init(
        id: UUID = UUID(),
        text: String,
        pageNumber: Int? = nil,
        aiSummary: String? = nil,
        userNotes: String? = nil,
        dateCreated: Date = Date(),
        book: Book? = nil
    ) {
        self.id = id
        self.text = text
        self.pageNumber = pageNumber
        self.aiSummary = aiSummary
        self.userNotes = userNotes
        self.dateCreated = dateCreated
        self.book = book
    }

    /// Preview of the passage text (first 100 characters)
    var textPreview: String {
        if text.count <= 100 {
            return text
        }
        return String(text.prefix(100)) + "..."
    }
}
