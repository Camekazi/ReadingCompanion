//
//  PassageTests.swift
//  ReadingCompanionTests
//
//  Tests for Passage model computed properties.
//

import Testing
import Foundation
@testable import ReadingCompanion

@Suite("Passage Model Tests")
struct PassageTests {

    // MARK: - textPreview Tests

    @Test("Returns full text when under 100 characters")
    func textPreview_returnsFullTextUnder100Chars() {
        // Given: A passage with short text
        let shortText = "This is a short passage."
        let passage = Passage(text: shortText)

        // When: Getting text preview
        let result = passage.textPreview

        // Then: Full text is returned without truncation
        #expect(result == shortText)
        #expect(!result.contains("..."))
    }

    @Test("Truncates with ellipsis when over 100 characters")
    func textPreview_truncatesOver100CharsWithEllipsis() {
        // Given: A passage with long text (> 100 chars)
        let longText = String(repeating: "a", count: 150)
        let passage = Passage(text: longText)

        // When: Getting text preview
        let result = passage.textPreview

        // Then: Text is truncated to 100 chars + ellipsis
        #expect(result.count == 103) // 100 chars + "..."
        #expect(result.hasSuffix("..."))
        #expect(result.hasPrefix(String(repeating: "a", count: 100)))
    }

    @Test("Returns full text when exactly 100 characters")
    func textPreview_handlesExactly100Chars() {
        // Given: A passage with exactly 100 characters
        let exactText = String(repeating: "x", count: 100)
        let passage = Passage(text: exactText)

        // When: Getting text preview
        let result = passage.textPreview

        // Then: Full text is returned (no truncation at exactly 100)
        #expect(result == exactText)
        #expect(result.count == 100)
        #expect(!result.contains("..."))
    }

    @Test("Handles empty text")
    func textPreview_handlesEmptyText() {
        // Given: A passage with empty text
        let passage = Passage(text: "")

        // When: Getting text preview
        let result = passage.textPreview

        // Then: Empty string is returned
        #expect(result.isEmpty)
    }

    @Test("Preserves whitespace and special characters")
    func textPreview_preservesWhitespaceAndSpecialChars() {
        // Given: A passage with whitespace and special characters
        let specialText = "Hello, World!\n\tThis has \"quotes\" and 'apostrophes'."
        let passage = Passage(text: specialText)

        // When: Getting text preview
        let result = passage.textPreview

        // Then: All characters are preserved
        #expect(result == specialText)
    }

    @Test("Truncates in the middle of a word")
    func textPreview_truncatesAtExact100Chars() {
        // Given: A passage where the 100th character is in the middle of a word
        let text = String(repeating: "word ", count: 25) // 125 chars (25 * 5)
        let passage = Passage(text: text)

        // When: Getting text preview
        let result = passage.textPreview

        // Then: Truncates at exactly 100 chars (doesn't try to find word boundary)
        #expect(result.count == 103) // 100 + "..."
        #expect(result.hasPrefix(String(text.prefix(100))))
    }
}
