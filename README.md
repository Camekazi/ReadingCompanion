# Reading Companion

An AI-powered iOS reading companion that helps you understand complex passages and track characters without spoilers.

## Features

- **Page Scanning**: Capture book pages with your camera using Apple Vision OCR
- **AI Explanations**: Get Claude-powered summaries, literary analysis, and vocabulary help
- **Spoiler-Free Character Queries**: Ask about characters based only on what you've read so far
- **Book Library**: Track your reading progress across multiple books
- **ISBN Scanning**: Scan barcodes to auto-populate book metadata from OpenLibrary

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Claude API key from [Anthropic](https://console.anthropic.com)

## Setup

1. Clone the repository:
   ```bash
   git clone https://github.com/YOUR_USERNAME/ReadingCompanion.git
   ```

2. Open in Xcode:
   ```bash
   open ReadingCompanion.xcodeproj
   ```

3. Build and run on a physical device (camera features require real hardware)

4. On first launch, go to **Settings** and enter your Claude API key

## Architecture

The app uses a **single-agent architecture** where every feature is a different prompt sent to Claude:

```
┌─────────────────────────────────────────────┐
│              SwiftUI App                     │
├─────────────────────────────────────────────┤
│  Camera View    →    OCR Service            │
│       ↓                   ↓                  │
│  Claude Service (feature prompts)           │
│       ↓                                      │
│  SwiftData (Book + Passage)                 │
└─────────────────────────────────────────────┘
```

### Key Components

| Component | Purpose |
|-----------|---------|
| `ClaudeService` | API integration with feature-specific prompts |
| `OCRService` | Apple Vision text recognition |
| `KeychainService` | Secure API key storage |
| `OpenLibraryService` | Book metadata lookup |

### Data Models

- **Book**: Title, author, ISBN, current page, total pages
- **Passage**: Scanned text, page number, AI summary

## Spoiler Protection

The killer feature: when you ask about a character, the app only sends passages from pages you've already read. Claude is instructed not to reveal anything beyond your current reading position.

```swift
// Passages are filtered to current reading position
let safePassages = book.passagesUpToCurrentPage
```

## Privacy

- Your Claude API key is stored in the iOS Keychain
- No data is sent to any server except Anthropic's API
- All OCR processing happens on-device

## License

MIT
