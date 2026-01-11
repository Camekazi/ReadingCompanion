//
//  PendingPassageService.swift
//  ReadingCompanion
//
//  Service for importing passages shared from the Share Extension.
//

import Foundation
import SwiftData

/// Represents a passage pending import from the Share Extension
struct PendingPassage: Codable {
    let bookTitle: String
    let pageNumber: Int?
    let text: String
    let dateAdded: Date
}

/// Service for handling passages shared via the Share Extension
@MainActor
class PendingPassageService {
    static let shared = PendingPassageService()

    private let appGroupIdentifier = "group.com.readingcompanion.shared"

    private var appGroupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    private var pendingPassagesURL: URL? {
        appGroupURL?.appendingPathComponent("pendingPassages.json")
    }

    /// Check if there are pending passages to import
    var hasPendingPassages: Bool {
        guard let url = pendingPassagesURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return false
        }

        let passages = loadPendingPassages()
        return !passages.isEmpty
    }

    /// Get the count of pending passages
    var pendingCount: Int {
        loadPendingPassages().count
    }

    /// Load all pending passages from the App Group container
    func loadPendingPassages() -> [PendingPassage] {
        guard let url = pendingPassagesURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingPassage].self, from: data)
        } catch {
            print("Failed to load pending passages: \(error)")
            return []
        }
    }

    /// Import all pending passages into the SwiftData database
    /// - Parameter context: The ModelContext to insert passages into
    /// - Returns: The number of passages imported
    @discardableResult
    func importPendingPassages(into context: ModelContext) -> Int {
        let pending = loadPendingPassages()
        guard !pending.isEmpty else { return 0 }

        var importedCount = 0

        for pendingPassage in pending {
            // Find or create book
            let book = findOrCreateBook(title: pendingPassage.bookTitle, context: context)

            // Create passage
            let passage = Passage(
                text: pendingPassage.text,
                pageNumber: pendingPassage.pageNumber,
                dateAdded: pendingPassage.dateAdded
            )
            passage.book = book
            book.passages.append(passage)

            context.insert(passage)
            importedCount += 1
        }

        // Save changes
        do {
            try context.save()

            // Clear pending passages after successful import
            clearPendingPassages()
        } catch {
            print("Failed to save imported passages: \(error)")
            return 0
        }

        return importedCount
    }

    /// Find an existing book by title or create a new one
    private func findOrCreateBook(title: String, context: ModelContext) -> Book {
        let titleLower = title.lowercased()

        // Try to find existing book
        let descriptor = FetchDescriptor<Book>()
        if let books = try? context.fetch(descriptor) {
            if let existingBook = books.first(where: { $0.title.lowercased() == titleLower }) {
                return existingBook
            }
        }

        // Create new book
        let newBook = Book(title: title)
        context.insert(newBook)
        return newBook
    }

    /// Clear all pending passages from the App Group container
    func clearPendingPassages() {
        guard let url = pendingPassagesURL else { return }

        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            // File might not exist, which is fine
        }
    }
}
