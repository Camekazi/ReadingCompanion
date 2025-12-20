//
//  ClaudeServiceTests.swift
//  ReadingCompanionTests
//
//  Tests for FeaturePrompts template generation.
//

import Testing
import Foundation
@testable import ReadingCompanion

@Suite("Claude Service Tests")
struct ClaudeServiceTests {

    // MARK: - passageExplanation Tests

    @Test("Passage explanation includes book title when provided")
    func passageExplanationPrompt_includesBookTitle() {
        // Given: A passage and book title
        let passage = "It was the best of times, it was the worst of times."
        let bookTitle = "A Tale of Two Cities"

        // When: Generating the prompt
        let prompt = FeaturePrompts.passageExplanation(text: passage, bookTitle: bookTitle)

        // Then: Prompt includes book title
        #expect(prompt.contains("Book: A Tale of Two Cities"))
        #expect(prompt.contains(passage))
        #expect(prompt.contains("Summary"))
        #expect(prompt.contains("Significance"))
        #expect(prompt.contains("Vocabulary"))
    }

    @Test("Passage explanation handles nil book title")
    func passageExplanationPrompt_handlesNilBookTitle() {
        // Given: A passage without book title
        let passage = "Call me Ishmael."

        // When: Generating the prompt
        let prompt = FeaturePrompts.passageExplanation(text: passage, bookTitle: nil)

        // Then: Prompt works without book reference
        #expect(!prompt.contains("Book:"))
        #expect(prompt.contains(passage))
        #expect(prompt.contains("Summary"))
    }

    @Test("Passage explanation preserves passage formatting")
    func passageExplanationPrompt_preservesFormatting() {
        // Given: A multi-line passage with special characters
        let passage = """
        "Hello," said Alice.
        "Goodbye," said the Cat.

        And with that, it vanished.
        """

        // When: Generating the prompt
        let prompt = FeaturePrompts.passageExplanation(text: passage, bookTitle: "Alice")

        // Then: Passage is included with formatting
        #expect(prompt.contains("\"Hello,\" said Alice."))
        #expect(prompt.contains("\"Goodbye,\" said the Cat."))
    }

    // MARK: - characterQuery Tests

    @Test("Character query formats passages correctly")
    func characterQueryPrompt_formatsPassagesCorrectly() {
        // Given: Character query parameters
        let passages = [
            "Gandalf appeared at the door.",
            "The wizard spoke softly.",
            "Gandalf raised his staff."
        ]

        // When: Generating the prompt
        let prompt = FeaturePrompts.characterQuery(
            characterName: "Gandalf",
            bookTitle: "The Hobbit",
            currentPage: 50,
            passages: passages
        )

        // Then: All passages are included, separated by dividers
        #expect(prompt.contains("Gandalf appeared at the door."))
        #expect(prompt.contains("The wizard spoke softly."))
        #expect(prompt.contains("Gandalf raised his staff."))
        #expect(prompt.contains("---"))
    }

    @Test("Character query includes spoiler protection")
    func characterQueryPrompt_includesSpoilerProtection() {
        // Given: Character query at specific page
        let currentPage = 100

        // When: Generating the prompt
        let prompt = FeaturePrompts.characterQuery(
            characterName: "Frodo",
            bookTitle: "LOTR",
            currentPage: currentPage,
            passages: ["Test passage"]
        )

        // Then: Spoiler protection is emphasized
        #expect(prompt.contains("WITHOUT SPOILERS"))
        #expect(prompt.contains("page \(currentPage)"))
        #expect(prompt.contains("Do NOT reveal anything that happens after page \(currentPage)"))
    }

    @Test("Character query includes character name and book")
    func characterQueryPrompt_includesCharacterAndBook() {
        // When: Generating the prompt
        let prompt = FeaturePrompts.characterQuery(
            characterName: "Hermione",
            bookTitle: "Harry Potter",
            currentPage: 200,
            passages: []
        )

        // Then: Character and book are mentioned
        #expect(prompt.contains("\"Hermione\""))
        #expect(prompt.contains("\"Harry Potter\""))
    }

    @Test("Character query handles empty passages")
    func characterQueryPrompt_handlesEmptyPassages() {
        // When: Generating with no passages
        let prompt = FeaturePrompts.characterQuery(
            characterName: "Unknown",
            bookTitle: "Mystery",
            currentPage: 1,
            passages: []
        )

        // Then: Prompt is still valid (passages section will be empty)
        #expect(prompt.contains("Unknown"))
        #expect(prompt.contains("Mystery"))
        #expect(prompt.contains("Passages:"))
    }

    // MARK: - ClaudeError Tests

    @Test("ClaudeError has descriptive messages")
    func claudeError_hasDescriptiveMessages() {
        // Test all error cases have user-friendly descriptions
        #expect(ClaudeError.noAPIKey.errorDescription?.contains("API key") == true)
        #expect(ClaudeError.invalidResponse.errorDescription?.contains("invalid") == true)
        #expect(ClaudeError.rateLimited.errorDescription?.contains("Rate limited") == true)
        #expect(ClaudeError.serverError(500).errorDescription?.contains("500") == true)

        // Network error wraps underlying error
        let networkError = ClaudeError.networkError(URLError(.notConnectedToInternet))
        #expect(networkError.errorDescription?.contains("Network error") == true)
    }
}
