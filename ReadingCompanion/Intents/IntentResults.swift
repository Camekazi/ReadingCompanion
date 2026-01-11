//
//  IntentResults.swift
//  ReadingCompanion
//
//  Shared result types for App Intents.
//

import AppIntents
import Foundation

/// Result returned when getting book information
struct BookInfoResult: Codable, Sendable {
    let title: String
    let author: String?
    let currentPage: Int
    let totalPages: Int?
    let progressPercentage: Double?
    let passageCount: Int
    let status: String

    init(from book: Book) {
        self.title = book.title
        self.author = book.author
        self.currentPage = book.currentPage
        self.totalPages = book.totalPages
        self.passageCount = book.passages.count

        if let total = book.totalPages, total > 0 {
            self.progressPercentage = (Double(book.currentPage) / Double(total)) * 100.0
        } else {
            self.progressPercentage = nil
        }

        if book.currentPage > 0 {
            self.status = "reading"
        } else {
            self.status = "unread"
        }
    }
}

/// Entity for book selection in App Intents
struct BookEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Book"
    static var defaultQuery = BookQuery()

    var id: UUID
    var title: String
    var author: String?

    var displayRepresentation: DisplayRepresentation {
        let subtitle = author ?? ""
        return DisplayRepresentation(title: "\(title)", subtitle: "\(subtitle)")
    }
}

/// Query for finding books by title
struct BookQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        let container = try ModelContainerProvider.shared.container
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Book>()
        let books = try context.fetch(descriptor)

        return books
            .filter { identifiers.contains($0.id) }
            .map { BookEntity(id: $0.id, title: $0.title, author: $0.author) }
    }

    func suggestedEntities() async throws -> [BookEntity] {
        let container = try ModelContainerProvider.shared.container
        let context = ModelContext(container)

        let descriptor = FetchDescriptor<Book>(sortBy: [SortDescriptor(\.dateLastRead, order: .reverse)])
        let books = try context.fetch(descriptor)

        return books.prefix(10).map { BookEntity(id: $0.id, title: $0.title, author: $0.author) }
    }
}

/// Provider for shared ModelContainer across intents
enum ModelContainerProvider {
    static let shared = ModelContainerProvider.self

    static var container: ModelContainer {
        get throws {
            let schema = Schema([Book.self, Passage.self, ReadingSession.self, VocabularyWord.self])
            let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        }
    }
}

/// Error types for App Intents
enum IntentError: LocalizedError {
    case bookNotFound(String)
    case noAPIKey
    case apiError(String)
    case noPassages

    var errorDescription: String? {
        switch self {
        case .bookNotFound(let title):
            return "Could not find a book matching '\(title)'"
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in the ReadingCompanion app settings."
        case .apiError(let message):
            return "API error: \(message)"
        case .noPassages:
            return "No passages have been scanned up to your current reading position."
        }
    }
}
