//
//  ExplainPassageIntent.swift
//  ReadingCompanion
//
//  App Intent for explaining a passage of text.
//  Uses Siri Shortcuts: "Explain this passage: [text]"
//

import AppIntents
import Foundation
import SwiftData

struct ExplainPassageIntent: AppIntent {
    static var title: LocalizedStringResource = "Explain Passage"
    static var description = IntentDescription("Get an AI explanation of a book passage, including summary, significance, and vocabulary.")

    static var openAppWhenRun: Bool = false

    @Parameter(title: "Passage Text")
    var passageText: String

    @Parameter(title: "Book Title (optional)")
    var bookTitle: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Explain \(\.$passageText)") {
            \.$bookTitle
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // Validate input
        let trimmedText = passageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return .result(value: "Please provide some text to explain.")
        }

        // Call ClaudeService
        let response = try await ClaudeService.shared.explainPassage(
            trimmedText,
            bookTitle: bookTitle
        )

        return .result(value: response)
    }
}
