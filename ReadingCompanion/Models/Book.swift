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

    // Free online version URLs (stored as strings for SwiftData compatibility)
    var openLibraryURL: String?
    var internetArchiveURL: String?

    // Audiobook (LibriVox) - Level 2 ready: storing ID allows fetching chapters later
    var librivoxURL: String?
    var librivoxId: String?          // For Level 2: fetch chapters on demand
    var librivoxDuration: String?    // e.g., "12:34:56"

    // Downloaded book content (for spoiler-free queries without scanning)
    var downloadedContent: Data?     // Encoded EPUBContent (chapters + text)
    var downloadedChapterCount: Int? // Number of chapters downloaded
    var downloadedWordCount: Int?    // Total words for progress estimation
    var currentChapter: Int?         // User's current chapter (0-indexed, nil = not set)

    // Sync tracking (for Obsidian bi-directional sync)
    var lastSyncDate: Date?          // When last synced with Obsidian
    var needsSync: Bool = false      // Has unsaved changes for export
    var sourceId: String?            // Original ID from Collective Bookshelf (for matching)
    var exportedFilePath: String?    // Path to exported .md file (for delete propagation)

    @Relationship(deleteRule: .cascade, inverse: \Passage.book)
    var passages: [Passage]

    @Relationship(deleteRule: .cascade, inverse: \ReadingSession.book)
    var readingSessions: [ReadingSession] = []

    @Relationship(deleteRule: .cascade, inverse: \VocabularyWord.book)
    var vocabularyWords: [VocabularyWord] = []

    init(
        id: UUID = UUID(),
        title: String,
        author: String? = nil,
        isbn: String? = nil,
        currentPage: Int = 0,
        totalPages: Int? = nil,
        dateAdded: Date = Date(),
        passages: [Passage] = [],
        openLibraryURL: String? = nil,
        internetArchiveURL: String? = nil,
        librivoxURL: String? = nil,
        librivoxId: String? = nil,
        librivoxDuration: String? = nil,
        currentChapter: Int = 0
    ) {
        self.id = id
        self.title = title
        self.author = author
        self.isbn = isbn
        self.currentPage = currentPage
        self.totalPages = totalPages
        self.dateAdded = dateAdded
        self.passages = passages
        self.openLibraryURL = openLibraryURL
        self.internetArchiveURL = internetArchiveURL
        self.librivoxURL = librivoxURL
        self.librivoxId = librivoxId
        self.librivoxDuration = librivoxDuration
        self.currentChapter = currentChapter
    }

    /// Whether this book has a free audiobook available
    var hasAudiobook: Bool {
        librivoxURL != nil
    }

    /// Whether this book has any free online versions available
    var hasFreeVersion: Bool {
        openLibraryURL != nil || internetArchiveURL != nil
    }

    /// Get all available free book sources
    var freeBookSources: [FreeBookSource] {
        var sources: [FreeBookSource] = []

        if let urlString = internetArchiveURL, let url = URL(string: urlString) {
            sources.append(FreeBookSource(
                name: "Internet Archive",
                url: url,
                type: .internetArchive
            ))
        }

        if let urlString = openLibraryURL, let url = URL(string: urlString) {
            sources.append(FreeBookSource(
                name: "Open Library",
                url: url,
                type: .openLibrary
            ))
        }

        return sources
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

    // MARK: - Downloaded Content Helpers

    /// Whether this book has downloaded content available
    var hasDownloadedContent: Bool {
        downloadedContent != nil
    }

    /// Cached decoded EPUB content (avoids repeated JSON parsing)
    @Transient private var _cachedEPUBContent: EPUBContent?

    /// Decode the downloaded EPUB content (cached for performance)
    var epubContent: EPUBContent? {
        if _cachedEPUBContent == nil, let data = downloadedContent {
            _cachedEPUBContent = try? JSONDecoder().decode(EPUBContent.self, from: data)
        }
        return _cachedEPUBContent
    }

    /// Store EPUB content (encodes to Data for SwiftData)
    func setEPUBContent(_ content: EPUBContent) {
        if let data = try? JSONEncoder().encode(content) {
            downloadedContent = data
            downloadedChapterCount = content.chapters.count
            downloadedWordCount = content.totalWordCount
            _cachedEPUBContent = content  // Update cache
        }
    }

    /// Get text content up to current chapter (for spoiler-free queries)
    var textUpToCurrentChapter: String? {
        epubContent?.textUpToChapter(currentChapter ?? 0)
    }

    /// Combined context for character queries: downloaded text OR scanned passages
    var characterQueryContext: String {
        // Prefer downloaded content if available (more complete)
        if let text = textUpToCurrentChapter, !text.isEmpty {
            return text
        }

        // Fall back to scanned passages
        return passagesUpToCurrentPage
            .map { $0.text }
            .joined(separator: "\n\n")
    }

    /// Extract Internet Archive ID from URL (for downloading)
    var internetArchiveId: String? {
        guard let urlString = internetArchiveURL,
              let url = URL(string: urlString) else { return nil }
        // URL format: https://archive.org/details/{id}
        return url.lastPathComponent
    }
}
