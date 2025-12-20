# ReadingCompanion

**Project Type**: iOS application (SwiftUI + SwiftData)
**Purpose**: AI-powered reading companion using Claude API for passage explanations and spoiler-free character queries
**Created**: 2025-12-06

---

## What This App Does

ReadingCompanion helps readers understand complex passages and track characters WITHOUT spoilers by:

1. **OCR Scanning**: Capture book passages via camera using Apple Vision framework
2. **Passage Explanation**: Get AI-powered summaries, vocabulary, and literary analysis
3. **Spoiler-Free Character Queries**: Ask about characters based ONLY on passages scanned up to current reading position
4. **Reading Progress Tracking**: Track page numbers and reading history per book

**Key Innovation**: Spoiler protection is enforced by limiting Claude's context to passages up to the user's current page number.

---

## Architecture Overview

### Data Models (SwiftData)

**Book.swift**
- Tracks books with title, author, ISBN, current/total pages
- Has one-to-many relationship with Passages (cascade delete)
- Computed property `passagesUpToCurrentPage` filters by current reading position for spoiler-free queries
- `progressDescription` formats reading progress display

**Passage.swift**
- Stores scanned text, page number, AI summary, user notes
- Belongs to one Book
- `textPreview` returns first 100 characters for list display

### Services Layer

**ClaudeService.swift** (`@MainActor`)
- Singleton service for Claude API (model: `claude-sonnet-4-20250514`)
- Two main features:
  - `explainPassage()`: Literary analysis with summary, significance, vocabulary
  - `queryCharacter()`: Spoiler-free character info using current page + scanned passages
- Uses KeychainService for secure API key retrieval
- Error handling: NoAPIKey, RateLimited, ServerError, InvalidResponse

**OCRService.swift**
- Apple Vision framework integration for text recognition
- `recognizeText()` returns OCRResult with text + confidence score
- Configured for accurate recognition, English language, language correction enabled
- Returns async result via `withCheckedThrowingContinuation`

**KeychainService.swift**
- Secure API key storage using iOS Keychain
- Service identifier: `com.readingcompanion.apikey`
- CRUD operations: save, get, delete API key
- `hasAPIKey` computed property for quick checks

**OpenLibraryService.swift**
- Fetches book metadata by ISBN from OpenLibrary API
- Returns BookMetadata: title, author, pageCount, publishYear, coverURL
- Also supports search by title/author
- Used for auto-populating book details when scanning ISBN barcodes

### Views (SwiftUI)

**ContentView.swift** (Main Navigation)
- TabView with 3 tabs: Library, Scan, Settings
- OnAppear checks for API key, prompts user if missing
- Alert redirects to Settings tab

**LibraryView.swift**
- Lists all books sorted by dateAdded (reverse)
- Search functionality by title/author
- Empty state with call-to-action
- Swipe-to-delete for books
- Navigation to BookDetailView

**SettingsView.swift**
- API key management with three states: no key (SecureField entry), existing key (show/hide toggle), save success alert
- Show/Hide button toggles between masked (••••••••) and plaintext display
- SecureField for API key entry with autocorrection disabled
- Remove API Key button (destructive role) for existing keys
- Links to Anthropic docs (https://docs.anthropic.com) and console (https://console.anthropic.com)
- Version 1.0.0, Build 1
- Placeholder for Export Library functionality (disabled)
- Footer text explains Keychain security and local-only storage
- OnAppear loads existing key state from KeychainService

**ScanView.swift** (assumed)
- Camera integration for capturing book passages
- OCR processing flow
- Page number input

**BookDetailView.swift** (assumed)
- Book reading progress
- List of scanned passages
- Character query interface
- Edit current page number

---

## Critical Implementation Details

### Spoiler Prevention Mechanism

```swift
// In Book.swift
var passagesUpToCurrentPage: [Passage] {
    passages
        .filter { ($0.pageNumber ?? 0) <= currentPage }
        .sorted { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }
}
```

This ensures character queries only have context from already-read pages.

### Claude API Integration

**Prompt Templates** (in `FeaturePrompts` enum):

1. **Passage Explanation**:
   - Summary (plain language)
   - Significance (themes, symbolism, literary devices)
   - Vocabulary (unusual/period-specific words)

2. **Character Query**:
   - CRITICAL instruction: "Do NOT reveal anything that happens after page X"
   - Includes book title, current page, filtered passages
   - Requests: first appearance, role/relationships, key traits so far

### API Key Security Flow

1. User enters API key in SettingsView (SecureField)
2. KeychainService stores in iOS Keychain with `kSecAttrAccessibleWhenUnlocked`
3. ClaudeService retrieves on-demand per request
4. ContentView checks on app launch, alerts if missing

---

## Dependencies

**Apple Frameworks**:
- SwiftUI (UI layer)
- SwiftData (persistence)
- Vision (OCR)
- Security (Keychain)
- Foundation (networking, data)

**External APIs**:
- Anthropic Claude API (`claude-sonnet-4-20250514`)
- OpenLibrary API (book metadata)

**Package.swift**: (check if Swift Package Manager dependencies exist)

---

## Key User Flows

### Flow 1: Add Book via ISBN
1. User taps "Add Book" in LibraryView
2. Scans ISBN barcode
3. OpenLibraryService fetches metadata
4. Book created with title, author, page count
5. User sets current page

### Flow 2: Scan and Explain Passage
1. User navigates to ScanView
2. Takes photo of book page
3. OCRService extracts text
4. User optionally edits OCR result
5. Passage saved with page number
6. User requests explanation
7. ClaudeService generates summary + analysis
8. AI summary stored with passage

### Flow 3: Spoiler-Free Character Query
1. User opens BookDetailView
2. Enters character name
3. App retrieves `passagesUpToCurrentPage`
4. ClaudeService receives ONLY passages up to current page
5. Claude responds with info revealed so far
6. Explicitly avoids future events

---

## Error Handling Patterns

**OCRError**:
- `imageConversionFailed`: UIImage → CGImage conversion failed
- `noTextFound`: Vision detected no text
- `processingFailed(Error)`: Vision framework error

**ClaudeError**:
- `noAPIKey`: Missing API key (prompts Settings navigation)
- `invalidResponse`: Malformed JSON from API
- `networkError(Error)`: URLSession error
- `rateLimited`: HTTP 429
- `serverError(Int)`: HTTP 5xx or other non-200

All errors conform to `LocalizedError` for user-friendly messages.

---

## Configuration

**Model Settings**:
- SwiftData schema: `[Book.self, Passage.self]`
- Storage: On-disk (not in-memory)
- Delete rule: Cascade (deleting book deletes passages)

**Claude API Settings**:
- Base URL: `https://api.anthropic.com/v1/messages`
- Model: `claude-sonnet-4-20250514`
- Max tokens: 2048
- API version header: `2023-06-01`

**OCR Settings**:
- Recognition level: Accurate
- Language correction: Enabled
- Languages: `["en-US", "en-GB"]`

---

## Testing Notes

**Preview Providers**:
- ContentView has `#Preview` with in-memory container
- Useful for SwiftUI previews without persistent data

**Security Testing**:
- API keys stored in Keychain, not UserDefaults
- Keys only transmitted in `x-api-key` header to Anthropic
- No plaintext API key storage

---

## Future Expansion Ideas

**From Code Placeholders**:
- Export library functionality (SettingsView has disabled button)
- Author name resolution in OpenLibraryService (currently skipped)

**Potential Features**:
- Multiple reading sessions per book
- Bookmarks and highlights
- Reading statistics and streaks
- Shared reading notes
- Offline mode (local LLM?)

---

## Build Info

**Version**: 1.0.0
**Build**: 1
**Platform**: iOS (requires camera, iOS Keychain)
**Xcode Project**: `ReadingCompanion.xcodeproj`

---

## Quick Reference

### Adding New Features

When adding new Claude-powered features:
1. Add prompt template to `FeaturePrompts` enum
2. Add method to `ClaudeService`
3. Consider spoiler implications (filter passages?)
4. Handle `ClaudeError` cases in UI
5. Update `max_tokens` if needed for longer responses

### Modifying Data Models

SwiftData models require migration:
1. Add `@Model` class changes
2. Update Schema in `ReadingCompanionApp.swift`
3. Test with in-memory container first
4. Consider data migration for existing users

---

**Last Updated**: 2025-12-06
**Status**: Initial codebase structure documented
