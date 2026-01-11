//
//  UpdateProgressIntent.swift
//  ReadingCompanion
//
//  App Intent for updating reading progress.
//  Uses Siri Shortcuts: "Update [book] to page [number]"
//

import AppIntents
import Foundation
import SwiftData

struct UpdateProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Update Reading Progress"
    static var description = IntentDescription("Update your current page in a book and create a reading session entry.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book Title")
    var bookTitle: String

    @Parameter(title: "Current Page")
    var currentPage: Int

    static var parameterSummary: some ParameterSummary {
        Summary("Update \(\.$bookTitle) to page \(\.$currentPage)")
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

        // 2. Calculate pages read
        let previousPage = book.currentPage
        let pagesRead = max(0, currentPage - previousPage)

        // 3. Update book progress
        book.currentPage = currentPage
        book.dateLastRead = Date()
        book.needsSync = true  // Mark for iCloud export

        // 4. Create reading session
        let session = ReadingSession(
            book: book,
            pagesRead: pagesRead,
            startPage: previousPage,
            endPage: currentPage
        )
        context.insert(session)

        // 5. Save changes
        try context.save()

        // 6. Auto-export to iCloud (if available)
        Task {
            try? ImportExportService.shared.exportBookToICloud(book)
        }

        // 7. Build response
        let progress = book.progressDescription
        var response = "Updated '\(book.title)' to page \(currentPage). \(progress)"

        if pagesRead > 0 {
            response += "\n\(pagesRead) pages read this session."
        }

        return .result(value: response)
    }
}
