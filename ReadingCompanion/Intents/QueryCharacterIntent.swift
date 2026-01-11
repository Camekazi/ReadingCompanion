//
//  QueryCharacterIntent.swift
//  ReadingCompanion
//
//  App Intent for asking about characters without spoilers.
//  Uses Siri Shortcuts: "Ask about [character] in [book]"
//

import AppIntents
import Foundation
import SwiftData

struct QueryCharacterIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask About Character"
    static var description = IntentDescription("Ask about a character in a book without spoilers. Only uses information up to your current reading position.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Book Title")
    var bookTitle: String

    @Parameter(title: "Character Name")
    var characterName: String

    static var parameterSummary: some ParameterSummary {
        Summary("Ask about \(\.$characterName) in \(\.$bookTitle)")
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

        // 2. Get spoiler-free context
        let context_text = book.characterQueryContext

        if context_text.isEmpty {
            throw IntentError.noPassages
        }

        // 3. Build position description
        let position: String
        if let chapter = book.currentChapter, chapter > 0 {
            position = "Chapter \(chapter)"
        } else if book.currentPage > 0 {
            position = "Page \(book.currentPage)"
        } else {
            position = "the beginning"
        }

        // 4. Call ClaudeService
        let response = try await ClaudeService.shared.queryCharacterWithContext(
            name: characterName,
            bookTitle: book.title,
            position: position,
            context: context_text
        )

        return .result(value: response)
    }
}

// MARK: - App Shortcuts Provider

struct ReadingCompanionShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: QueryCharacterIntent(),
            phrases: [
                "Ask about \(\.$characterName) in \(\.$bookTitle) with \(.applicationName)",
                "Tell me about \(\.$characterName) in \(\.$bookTitle) using \(.applicationName)",
                "Who is \(\.$characterName) in \(\.$bookTitle)"
            ],
            shortTitle: "Ask About Character",
            systemImageName: "person.fill.questionmark"
        )

        AppShortcut(
            intent: ExplainPassageIntent(),
            phrases: [
                "Explain this passage with \(.applicationName)",
                "What does this mean in \(.applicationName)"
            ],
            shortTitle: "Explain Passage",
            systemImageName: "text.magnifyingglass"
        )

        AppShortcut(
            intent: UpdateProgressIntent(),
            phrases: [
                "Update \(\.$bookTitle) to page \(\.$currentPage) in \(.applicationName)",
                "I'm on page \(\.$currentPage) of \(\.$bookTitle)"
            ],
            shortTitle: "Update Reading Progress",
            systemImageName: "book.fill"
        )

        AppShortcut(
            intent: GetBookInfoIntent(),
            phrases: [
                "Get info about \(\.$bookTitle) from \(.applicationName)",
                "How far am I in \(\.$bookTitle)"
            ],
            shortTitle: "Get Book Info",
            systemImageName: "info.circle"
        )
    }
}
