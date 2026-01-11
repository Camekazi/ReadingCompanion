//
//  ClaudeService.swift
//  ReadingCompanion
//
//  Service for interacting with Claude API for passage explanations
//  and character queries.
//

import Foundation

/// Errors that can occur when interacting with Claude API
enum ClaudeError: LocalizedError {
    case noAPIKey
    case invalidResponse
    case networkError(Error)
    case rateLimited
    case serverError(Int)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "No API key configured. Please add your Claude API key in Settings."
        case .invalidResponse:
            return "Received an invalid response from Claude."
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .rateLimited:
            return "Rate limited. Please wait a moment and try again."
        case .serverError(let code):
            return "Server error (code \(code)). Please try again later."
        }
    }
}

/// Result from passage explanation containing both text and extracted vocabulary
struct PassageExplanationResult {
    let explanation: String
    let vocabulary: [ExtractedVocabulary]
}

/// Service for Claude API interactions
@MainActor
class ClaudeService: ObservableObject {
    static let shared = ClaudeService()

    @Published var isLoading = false

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let model = "claude-sonnet-4-20250514"

    private init() {}

    /// Get API key from Keychain
    private var apiKey: String? {
        KeychainService.shared.getAPIKey()
    }

    /// Explain a passage from a book
    func explainPassage(_ text: String, bookTitle: String? = nil) async throws -> String {
        let prompt = FeaturePrompts.passageExplanation(text: text, bookTitle: bookTitle)
        return try await sendMessage(prompt)
    }

    /// Explain a passage and extract vocabulary words
    func explainPassageWithVocabulary(_ text: String, bookTitle: String? = nil) async throws -> PassageExplanationResult {
        let prompt = FeaturePrompts.passageExplanationWithVocabulary(text: text, bookTitle: bookTitle)
        let response = try await sendMessage(prompt)

        // Parse the response to separate explanation from vocabulary JSON
        return parseExplanationWithVocabulary(response, originalText: text)
    }

    /// Parse Claude's response to extract explanation text and vocabulary JSON
    private func parseExplanationWithVocabulary(_ response: String, originalText: String) -> PassageExplanationResult {
        // Look for the JSON vocabulary block at the end
        let jsonMarker = "```json"
        let endMarker = "```"

        guard let jsonStart = response.range(of: jsonMarker) else {
            // No JSON block found, return explanation only
            return PassageExplanationResult(explanation: response, vocabulary: [])
        }

        // Extract explanation (everything before the JSON block)
        let explanation = String(response[..<jsonStart.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Extract JSON content
        let afterMarker = response[jsonStart.upperBound...]
        guard let jsonEnd = afterMarker.range(of: endMarker) else {
            return PassageExplanationResult(explanation: explanation, vocabulary: [])
        }

        let jsonString = String(afterMarker[..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse JSON into vocabulary words
        guard let jsonData = jsonString.data(using: .utf8) else {
            return PassageExplanationResult(explanation: explanation, vocabulary: [])
        }

        do {
            let vocabResponse = try JSONDecoder().decode(VocabularyExtractionResponse.self, from: jsonData)
            return PassageExplanationResult(explanation: explanation, vocabulary: vocabResponse.words)
        } catch {
            // Try parsing as array directly (in case Claude returns just the array)
            if let words = try? JSONDecoder().decode([ExtractedVocabulary].self, from: jsonData) {
                return PassageExplanationResult(explanation: explanation, vocabulary: words)
            }
            return PassageExplanationResult(explanation: explanation, vocabulary: [])
        }
    }

    /// Query about a character with spoiler protection (legacy - uses passages)
    func queryCharacter(
        name: String,
        bookTitle: String,
        currentPage: Int,
        passages: [String]
    ) async throws -> String {
        let prompt = FeaturePrompts.characterQuery(
            characterName: name,
            bookTitle: bookTitle,
            currentPage: currentPage,
            passages: passages
        )
        return try await sendMessage(prompt)
    }

    /// Query about a character with combined context (downloaded text or passages)
    func queryCharacterWithContext(
        name: String,
        bookTitle: String,
        position: String,
        context: String
    ) async throws -> String {
        let prompt = FeaturePrompts.characterQueryWithContext(
            characterName: name,
            bookTitle: bookTitle,
            position: position,
            context: context
        )
        return try await sendMessage(prompt)
    }

    /// Send a message to Claude API
    private func sendMessage(_ content: String) async throws -> String {
        guard let apiKey = apiKey else {
            throw ClaudeError.noAPIKey
        }

        isLoading = true
        defer { isLoading = false }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClaudeError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            break
        case 429:
            throw ClaudeError.rateLimited
        case 500...599:
            throw ClaudeError.serverError(httpResponse.statusCode)
        default:
            if httpResponse.statusCode != 200 {
                throw ClaudeError.serverError(httpResponse.statusCode)
            }
        }

        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw ClaudeError.invalidResponse
        }

        return text
    }
}

/// Feature-specific prompt templates
enum FeaturePrompts {

    static func passageExplanation(text: String, bookTitle: String?) -> String {
        """
        You are a literary assistant helping a reader understand a passage.

        \(bookTitle.map { "Book: \($0)" } ?? "")

        Passage:
        ---
        \(text)
        ---

        Provide:
        1. **Summary**: What's happening in plain language
        2. **Significance**: Any themes, symbolism, or literary devices (if notable)
        3. **Vocabulary**: Define any unusual or period-specific words

        Be helpful and concise. The reader wants to understand, not receive a lecture.
        """
    }

    static func passageExplanationWithVocabulary(text: String, bookTitle: String?) -> String {
        """
        You are a literary assistant helping a reader understand a passage.

        \(bookTitle.map { "Book: \($0)" } ?? "")

        Passage:
        ---
        \(text)
        ---

        Provide:
        1. **Summary**: What's happening in plain language
        2. **Significance**: Any themes, symbolism, or literary devices (if notable)
        3. **Vocabulary**: Explain any unusual, archaic, or period-specific words inline

        Be helpful and concise. The reader wants to understand, not receive a lecture.

        After your explanation, provide a JSON block with vocabulary words extracted from the passage.
        Include words that a modern reader might not immediately understand, or that have special meaning in context.
        Format:

        ```json
        {"words": [
            {"word": "the word", "definition": "clear definition", "partOfSpeech": "noun/verb/etc", "context": "the phrase from the passage where it appears"},
            ...
        ]}
        ```

        If there are no notable vocabulary words, return an empty array: {"words": []}
        """
    }

    static func characterQuery(
        characterName: String,
        bookTitle: String,
        currentPage: Int,
        passages: [String]
    ) -> String {
        """
        You are helping a reader understand a character WITHOUT SPOILERS.

        Book: "\(bookTitle)"
        Reader's current page: \(currentPage)

        Based ONLY on the passages below (scanned by the reader up to page \(currentPage)),
        tell me about the character "\(characterName)".

        CRITICAL: Do NOT reveal anything that happens after page \(currentPage).
        If the character hasn't appeared in the provided passages, say so.

        Include:
        - When/how they first appear
        - Their role and relationships to other characters
        - Key traits revealed so far

        Passages:
        ---
        \(passages.joined(separator: "\n---\n"))
        ---
        """
    }

    static func characterQueryWithContext(
        characterName: String,
        bookTitle: String,
        position: String,
        context: String
    ) -> String {
        """
        You are helping a reader understand a character WITHOUT SPOILERS.

        Book: "\(bookTitle)"
        Reader's current position: \(position)

        Based ONLY on the text below (up to the reader's current position),
        tell me about the character "\(characterName)".

        CRITICAL: Do NOT reveal anything beyond \(position).
        If the character hasn't appeared in the provided text, say so.

        Include:
        - When/how they first appear
        - Their role and relationships to other characters
        - Key traits revealed so far

        Text (up to \(position)):
        ---
        \(context)
        ---
        """
    }
}
