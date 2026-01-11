//
//  VocabularyWord.swift
//  ReadingCompanion
//
//  SwiftData model for storing vocabulary words extracted from passages.
//

import Foundation
import SwiftData

@Model
final class VocabularyWord {
    var id: UUID
    var word: String                // The vocabulary word
    var definition: String          // AI-provided definition
    var context: String?            // Original sentence/context from passage
    var partOfSpeech: String?       // noun, verb, adjective, etc.
    var dateAdded: Date
    var isMastered: Bool            // User marks as learned

    var book: Book?
    var passage: Passage?           // Optional link to source passage

    init(
        id: UUID = UUID(),
        word: String,
        definition: String,
        context: String? = nil,
        partOfSpeech: String? = nil,
        dateAdded: Date = Date(),
        isMastered: Bool = false,
        book: Book? = nil,
        passage: Passage? = nil
    ) {
        self.id = id
        self.word = word
        self.definition = definition
        self.context = context
        self.partOfSpeech = partOfSpeech
        self.dateAdded = dateAdded
        self.isMastered = isMastered
        self.book = book
        self.passage = passage
    }

    /// Formatted part of speech (capitalized, with parentheses)
    var formattedPartOfSpeech: String? {
        guard let pos = partOfSpeech, !pos.isEmpty else { return nil }
        return "(\(pos))"
    }
}

// MARK: - Vocabulary Extraction

/// Represents a vocabulary word extracted from Claude's response
struct ExtractedVocabulary: Codable {
    let word: String
    let definition: String
    let partOfSpeech: String?
    let context: String?
}

/// Response structure for vocabulary extraction
struct VocabularyExtractionResponse: Codable {
    let words: [ExtractedVocabulary]
}

// MARK: - Vocabulary Statistics

struct VocabularyStats {
    let totalWords: Int
    let masteredWords: Int
    let wordsThisWeek: Int
    let uniqueBooks: Int

    var masteryPercentage: Double {
        guard totalWords > 0 else { return 0 }
        return Double(masteredWords) / Double(totalWords) * 100
    }

    var masteryDisplay: String {
        String(format: "%.0f%%", masteryPercentage)
    }

    static let empty = VocabularyStats(
        totalWords: 0,
        masteredWords: 0,
        wordsThisWeek: 0,
        uniqueBooks: 0
    )
}
