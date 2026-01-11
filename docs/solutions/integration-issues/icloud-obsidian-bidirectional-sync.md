# iCloud-Obsidian Bi-directional Sync

## Metadata
- **created**: 2025-12-29
- **category**: integration
- **components**: [ImportExportService, DocumentPickerView, Book model, iCloud Documents]
- **severity**: feature-implementation
- **status**: implemented

---

## Problem Statement

Enable data flow in both directions between ReadingCompanion iOS app and Obsidian Collective Bookshelf:
- **Import**: Obsidian Collective Bookshelf (454 books via CSV) → ReadingCompanion
- **Export**: ReadingCompanion books & passages → Obsidian vault (Markdown with YAML frontmatter)

---

## Root Cause Analysis

### Why This Approach

1. **iCloud Documents vs CloudKit**: For small markdown files with async sync, iCloud Documents provides free automatic multi-device sync without CloudKit complexity
2. **YAML Frontmatter**: Obsidian's native metadata format ensures interoperability
3. **CSV Import**: Notion/Collective Bookshelf exports to CSV, requiring quote-aware parsing

### Build Integration Challenges

New Swift files must be registered in **4 sections** of `project.pbxproj`:
1. `PBXBuildFile` - Build phase references
2. `PBXFileReference` - File path declarations
3. `PBXGroup` - Folder hierarchy (children arrays)
4. `PBXSourcesBuildPhase` - Compilation order

Missing any section causes "cannot find X in scope" errors even when files exist in filesystem.

---

## Solution

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ImportExportService                       │
├─────────────────────────────────────────────────────────────┤
│  CSV Import                    │  Markdown Export            │
│  ───────────                   │  ────────────────           │
│  parseCSV() → [BookMetadata]   │  exportToMarkdown(Book)     │
│  importBooks() → ImportResult  │  exportAllBooks()           │
│                                │  getICloudURL()             │
└─────────────────────────────────────────────────────────────┘
                    │
                    ▼
┌─────────────────────────────────────────────────────────────┐
│                      iCloud Documents                        │
│  Container: iCloud.com.camekazi.ReadingCompanion            │
│  Path: Documents/ReadingCompanion/*.md                      │
└─────────────────────────────────────────────────────────────┘
```

### Key Files

| File | Purpose |
|------|---------|
| `Services/ImportExportService.swift` | CSV parsing, markdown generation, iCloud sync |
| `Views/DocumentPickerView.swift` | UIDocumentPickerViewController wrapper |
| `Models/Book.swift` | Added `lastSyncDate`, `needsSync`, `sourceId`, `exportedFilePath` |
| `ReadingCompanion.entitlements` | iCloud Documents capability |

### Code Examples

#### CSV Import (Quote-Aware Parser)

```swift
private func parseCSVLine(_ line: String) -> [String] {
    var fields: [String] = []
    var current = ""
    var inQuotes = false

    for char in line {
        if char == "\"" {
            inQuotes.toggle()
        } else if char == "," && !inQuotes {
            fields.append(current.trimmingCharacters(in: .whitespaces))
            current = ""
        } else {
            current.append(char)
        }
    }
    fields.append(current.trimmingCharacters(in: .whitespaces))
    return fields
}
```

#### Markdown Export with YAML Frontmatter

```swift
func exportToMarkdown(book: Book) -> String {
    var md = """
    ---
    title: "\(book.title)"
    author: "\(book.author ?? "Unknown")"
    isbn: "\(book.isbn ?? "")"
    current_page: \(book.currentPage)
    total_pages: \(book.totalPages)
    date_added: \(ISO8601DateFormatter().string(from: book.dateAdded))
    source_id: "\(book.id.uuidString)"
    ---

    # \(book.title)

    """

    if !book.passages.isEmpty {
        md += "## Passages\n\n"
        for passage in book.passages.sorted(by: { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }) {
            md += "### Page \(passage.pageNumber ?? 0)\n"
            md += "> \(passage.text)\n\n"
            if let summary = passage.aiSummary {
                md += "**AI Summary**: \(summary)\n\n"
            }
        }
    }
    return md
}
```

#### iCloud Documents URL

```swift
func getICloudDocumentsURL() -> URL? {
    guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
        return nil  // iCloud not available
    }
    let documentsURL = containerURL
        .appendingPathComponent("Documents")
        .appendingPathComponent("ReadingCompanion")

    try? FileManager.default.createDirectory(at: documentsURL,
                                              withIntermediateDirectories: true)
    return documentsURL
}
```

#### NSFileCoordinator for Safe Writes

```swift
func writeToICloud(content: String, filename: String) throws {
    guard let icloudURL = getICloudDocumentsURL() else {
        throw ExportError.iCloudNotAvailable
    }

    let fileURL = icloudURL.appendingPathComponent(filename)
    let coordinator = NSFileCoordinator()
    var coordinatorError: NSError?

    coordinator.coordinate(writingItemAt: fileURL, options: .forReplacing, error: &coordinatorError) { url in
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    if let error = coordinatorError {
        throw error
    }
}
```

### Entitlements Configuration

```xml
<!-- ReadingCompanion.entitlements -->
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.camekazi.ReadingCompanion</string>
</array>
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudDocuments</string>
</array>
<key>com.apple.developer.ubiquity-container-identifiers</key>
<array>
    <string>iCloud.com.camekazi.ReadingCompanion</string>
</array>
```

---

## CRUD Completeness: Delete Propagation

When a book is deleted in the app, the exported markdown file must also be removed:

```swift
func deleteBook(_ book: Book, context: ModelContext) {
    // 1. Delete iCloud file if exists
    if let exportPath = book.exportedFilePath,
       let icloudURL = getICloudDocumentsURL() {
        let fileURL = icloudURL.appendingPathComponent(exportPath)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // 2. Delete from SwiftData
    context.delete(book)
}
```

---

## Verification

### Build Verification

```bash
# Verify project recognizes new files
xcodebuild -list -project ReadingCompanion.xcodeproj

# Build for simulator
xcodebuild build \
  -scheme ReadingCompanion \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_ALLOWED=NO
```

### Runtime Verification

1. **Import Test**: Settings → Import Library → Select CSV → Verify book count
2. **Export Test**: Book Detail → Export → Check Files app → iCloud Drive → ReadingCompanion
3. **Delete Test**: Delete book → Verify .md file removed from iCloud

---

## Prevention Strategies

### When Adding New Files to Xcode Project

Always update **all 4 sections** in `project.pbxproj`:

```
# Checklist for new .swift file:
□ PBXBuildFile section (compile reference)
□ PBXFileReference section (file path)
□ PBXGroup children (folder hierarchy)
□ PBXSourcesBuildPhase files (build order)
```

### iCloud Fallback

```swift
// Always handle iCloud unavailable case
if FileManager.default.url(forUbiquityContainerIdentifier: nil) == nil {
    // Fallback to UIDocumentPicker for manual export
    showDocumentPicker()
}
```

### Simulator Compatibility

iPhone simulators update with Xcode versions. Always check available simulators:

```bash
xcrun simctl list devices available | grep iPhone
```

---

## Related Documentation

- [CLAUDE.md](/Users/joppa/Projects/ReadingCompanion/CLAUDE.md) - Project architecture overview
- [Plan File](/.claude/plans/elegant-stirring-nebula.md) - Original implementation plan
- [ios-xcode.md](~/.claude/rules/ios-xcode.md) - Xcode development rules including project.pbxproj editing

---

## Tags

#ios #icloud #swiftdata #obsidian #sync #import-export #phase-work
