//
//  GetBookInfoIntent.swift
//  ReadingCompanion
//
//  App Intent for getting book information.
//  Uses Siri Shortcuts: "Get info about [book]"
//

import AppIntents
import Foundation
import SwiftData

struct GetBookInfoIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Book Info"
    static var description = IntentDescription("Get information about a book including progress, page count, and number of saved passages.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book Title")
    var bookTitle: String

    static var parameterSummary: some ParameterSummary {
        Summary("Get info about \(\.$bookTitle)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // 1. Find book by title
        let container = try ModelContainerProvider.container
        let context = ModelContext(container)

        let titleLower = bookTitle.lowercased()
        let descriptor = FetchDescriptor<Book>()
        let books = try context.fetch(descriptor)

        guard let book = books.first(where: { $0.title.lowercased().contains(titleLower) }) else {
            throw IntentError.bookNotFound(bookTitle)
        }

        // 2. Build info response
        var info = "📚 \(book.title)"

        if let author = book.author, !author.isEmpty {
            info += "\nby \(author)"
        }

        // 3. Progress info
        info += "\n\n📖 Progress:"
        info += "\n• Current page: \(book.currentPage)"

        if let total = book.totalPages, total > 0 {
            let percentage = Int((Double(book.currentPage) / Double(total)) * 100)
            info += " of \(total) (\(percentage)%)"
        }

        if let chapter = book.currentChapter, chapter > 0 {
            info += "\n• Current chapter: \(chapter)"
        }

        // 4. Content stats
        let passageCount = book.passages.count
        info += "\n\n📝 Content:"
        info += "\n• Saved passages: \(passageCount)"

        // Count passages with AI summaries
        let summarizedCount = book.passages.filter { $0.aiSummary != nil }.count
        if summarizedCount > 0 {
            info += "\n• With AI summaries: \(summarizedCount)"
        }

        // 5. Reading activity
        if let lastRead = book.dateLastRead {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            let relativeDate = formatter.localizedString(for: lastRead, relativeTo: Date())
            info += "\n\n🕐 Last read: \(relativeDate)"
        }

        // 6. Status
        let status: String
        if book.currentPage == 0 {
            status = "Not started"
        } else if let total = book.totalPages, book.currentPage >= total {
            status = "Completed"
        } else {
            status = "Currently reading"
        }
        info += "\n📊 Status: \(status)"

        return .result(value: info)
    }
}
