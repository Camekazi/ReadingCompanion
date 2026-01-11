//
//  ImportExportService.swift
//  ReadingCompanion
//
//  Service for importing from Obsidian Collective Bookshelf and exporting to iCloud Documents.
//  Follows agent-native patterns: CRUD completeness, iCloud Documents, NSFileCoordinator.
//

import Foundation
import SwiftData

/// Service handling import/export between ReadingCompanion and Obsidian
@MainActor
final class ImportExportService {
    static let shared = ImportExportService()

    private init() {}

    // MARK: - iCloud Documents

    /// Get the iCloud Documents container URL for exports
    var iCloudContainerURL: URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents")
            .appendingPathComponent("ReadingCompanion")
    }

    /// Check if iCloud is available
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    /// Ensure the export directory exists
    func ensureExportDirectoryExists() throws {
        guard let containerURL = iCloudContainerURL else {
            throw ImportExportError.iCloudNotAvailable
        }

        if !FileManager.default.fileExists(atPath: containerURL.path) {
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        }
    }

    // MARK: - CSV Import

    /// Import books from Collective Bookshelf CSV
    func importFromCSV(url: URL, modelContext: ModelContext) async throws -> ImportResult {
        let csvContent = try String(contentsOf: url, encoding: .utf8)
        let rows = parseCSV(csvContent)

        guard !rows.isEmpty else {
            throw ImportExportError.emptyFile
        }

        // First row is headers
        let headers = rows[0]
        let dataRows = Array(rows.dropFirst())

        var imported = 0
        var skipped = 0
        var errors: [String] = []

        // Build header index for flexible column mapping
        let headerIndex = Dictionary(uniqueKeysWithValues: headers.enumerated().map { ($1, $0) })

        for row in dataRows {
            do {
                let book = try parseBookRow(row, headerIndex: headerIndex, modelContext: modelContext)
                if let book = book {
                    modelContext.insert(book)
                    imported += 1
                } else {
                    skipped += 1
                }
            } catch {
                errors.append(error.localizedDescription)
                skipped += 1
            }
        }

        return ImportResult(imported: imported, skipped: skipped, errors: errors)
    }

    /// Parse a single CSV row into a Book (returns nil if duplicate)
    private func parseBookRow(_ row: [String], headerIndex: [String: Int], modelContext: ModelContext) throws -> Book? {
        func getValue(_ column: String) -> String? {
            guard let index = headerIndex[column], index < row.count else { return nil }
            let value = row[index].trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }

        guard let title = getValue("Title"), !title.isEmpty else {
            throw ImportExportError.missingRequiredField("Title")
        }

        // Check for duplicates by ISBN or title+author
        let isbn13 = getValue("ISBN_13")
        let isbn10 = getValue("ISBN_10")
        let isbn = isbn13 ?? isbn10
        let author = getValue("Author")

        if try isDuplicate(title: title, author: author, isbn: isbn, modelContext: modelContext) {
            return nil // Skip duplicate
        }

        // Parse page count
        var totalPages: Int? = nil
        if let pageCountStr = getValue("Page Count") {
            totalPages = Int(pageCountStr)
        }

        // Parse current page from "Reading Progress (Page)"
        var currentPage = 0
        if let pageStr = getValue("Reading Progress (Page)") {
            currentPage = Int(pageStr) ?? 0
        }

        let book = Book(
            title: title,
            author: author,
            isbn: isbn,
            currentPage: currentPage,
            totalPages: totalPages
        )

        // Store source ID for sync tracking (use title as identifier)
        book.sourceId = title.lowercased().replacingOccurrences(of: " ", with: "-")

        return book
    }

    /// Check if a book already exists
    private func isDuplicate(title: String, author: String?, isbn: String?, modelContext: ModelContext) throws -> Bool {
        // Check by ISBN first (most reliable)
        if let isbn = isbn {
            let isbnPredicate = #Predicate<Book> { book in
                book.isbn == isbn
            }
            let descriptor = FetchDescriptor<Book>(predicate: isbnPredicate)
            let matches = try modelContext.fetch(descriptor)
            if !matches.isEmpty { return true }
        }

        // Check by title + author
        let titleLower = title.lowercased()
        let authorLower = author?.lowercased()

        let descriptor = FetchDescriptor<Book>()
        let allBooks = try modelContext.fetch(descriptor)

        return allBooks.contains { book in
            let bookTitleMatch = book.title.lowercased() == titleLower
            let bookAuthorMatch = authorLower == nil || book.author?.lowercased() == authorLower
            return bookTitleMatch && bookAuthorMatch
        }
    }

    /// Parse CSV content into rows and columns
    private func parseCSV(_ content: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in content {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if char == "\n" && !insideQuotes {
                currentRow.append(currentField)
                if !currentRow.allSatisfy({ $0.isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
                currentField = ""
            } else if char != "\r" {
                currentField.append(char)
            }
        }

        // Handle last field/row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    // MARK: - Markdown Export

    /// Export a single book to markdown
    func exportBook(_ book: Book) throws -> String {
        var markdown = "---\n"

        // YAML frontmatter
        markdown += "title: \"\(escapeYAML(book.title))\"\n"
        if let author = book.author {
            markdown += "author: \"\(escapeYAML(author))\"\n"
        }
        if let isbn = book.isbn {
            markdown += "isbn: \"\(isbn)\"\n"
        }
        markdown += "current_page: \(book.currentPage)\n"
        if let totalPages = book.totalPages {
            markdown += "total_pages: \(totalPages)\n"
        }
        markdown += "date_added: \(formatDate(book.dateAdded))\n"
        if let dateLastRead = book.dateLastRead {
            markdown += "date_last_read: \(formatDate(dateLastRead))\n"
        }
        markdown += "source_id: \"\(book.id.uuidString)\"\n"
        markdown += "status: \(book.currentPage > 0 ? "reading" : "unread")\n"
        markdown += "---\n\n"

        // Title
        markdown += "# \(book.title)\n\n"

        // Passages section
        if !book.passages.isEmpty {
            markdown += "## Passages\n\n"

            let sortedPassages = book.passages.sorted { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }
            for passage in sortedPassages {
                if let pageNumber = passage.pageNumber {
                    markdown += "### Page \(pageNumber)"
                } else {
                    markdown += "### Passage"
                }
                markdown += " (\(formatDate(passage.dateCreated)))\n\n"

                markdown += "> \(passage.text.replacingOccurrences(of: "\n", with: "\n> "))\n\n"

                if let summary = passage.aiSummary, !summary.isEmpty {
                    markdown += "**AI Summary**: \(summary)\n\n"
                }

                if let notes = passage.userNotes, !notes.isEmpty {
                    markdown += "**Notes**: \(notes)\n\n"
                }
            }
        }

        return markdown
    }

    /// Export book to iCloud Documents (with NSFileCoordinator)
    func exportBookToICloud(_ book: Book) throws {
        try ensureExportDirectoryExists()

        guard let containerURL = iCloudContainerURL else {
            throw ImportExportError.iCloudNotAvailable
        }

        let markdown = try exportBook(book)
        let fileName = sanitizeFileName(book.title) + ".md"
        let fileURL = containerURL.appendingPathComponent(fileName)

        // Use NSFileCoordinator for safe iCloud writes
        var coordinatorError: NSError?
        var writeError: Error?

        let coordinator = NSFileCoordinator()
        coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
            do {
                try markdown.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                writeError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = writeError {
            throw error
        }

        // Update book's exported file path for delete propagation
        book.exportedFilePath = fileURL.path
        book.lastSyncDate = Date()
        book.needsSync = false
    }

    /// Export all books to iCloud Documents
    func exportAllBooksToICloud(_ books: [Book]) throws -> ExportResult {
        var exported = 0
        var errors: [String] = []

        for book in books {
            do {
                try exportBookToICloud(book)
                exported += 1
            } catch {
                errors.append("\(book.title): \(error.localizedDescription)")
            }
        }

        return ExportResult(exported: exported, errors: errors)
    }

    // MARK: - Delete Propagation (CRUD Completeness)

    /// Delete the exported file when a book is deleted
    func deleteExportedFile(for book: Book) {
        guard let pathString = book.exportedFilePath else { return }

        let fileURL = URL(fileURLWithPath: pathString)

        var coordinatorError: NSError?
        let coordinator = NSFileCoordinator()

        coordinator.coordinate(writingItemAt: fileURL, options: .forDeleting, error: &coordinatorError) { url in
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    private func escapeYAML(_ string: String) -> String {
        string.replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.string(from: date)
    }

    private func sanitizeFileName(_ name: String) -> String {
        let invalidChars = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return name
            .components(separatedBy: invalidChars)
            .joined()
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .trimmingCharacters(in: .punctuationCharacters)
    }
}

// MARK: - Result Types

struct ImportResult {
    let imported: Int
    let skipped: Int
    let errors: [String]

    var summary: String {
        var text = "Imported \(imported) book\(imported == 1 ? "" : "s")"
        if skipped > 0 {
            text += ", skipped \(skipped) duplicate\(skipped == 1 ? "" : "s")"
        }
        return text
    }
}

struct ExportResult {
    let exported: Int
    let errors: [String]

    var summary: String {
        var text = "Exported \(exported) book\(exported == 1 ? "" : "s")"
        if !errors.isEmpty {
            text += " (\(errors.count) error\(errors.count == 1 ? "" : "s"))"
        }
        return text
    }
}

// MARK: - Errors

enum ImportExportError: LocalizedError {
    case iCloudNotAvailable
    case emptyFile
    case missingRequiredField(String)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please sign in to iCloud in Settings."
        case .emptyFile:
            return "The file is empty or could not be read."
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .parseError(let details):
            return "Failed to parse: \(details)"
        }
    }
}
