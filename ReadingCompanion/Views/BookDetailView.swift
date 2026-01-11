//
//  BookDetailView.swift
//  ReadingCompanion
//
//  Detail view for a single book showing passages and character queries.
//

import SwiftUI
import SwiftData

struct BookDetailView: View {
    @Bindable var book: Book
    @Environment(\.modelContext) private var modelContext

    @State private var showingCharacterQuery = false
    @State private var showingUpdatePage = false
    @State private var showingUpdateChapter = false
    @State private var isDownloading = false
    @State private var downloadError: String?
    @State private var hasTextVersion: Bool?  // nil = checking, true/false = result

    // Export state
    @State private var isExporting = false
    @State private var showingExportSuccess = false
    @State private var exportError: String?

    var body: some View {
        List {
            // Book Info Section
            Section("Reading Progress") {
                HStack {
                    VStack(alignment: .leading) {
                        Text(book.progressDescription)
                            .font(.headline)
                        if let author = book.author {
                            Text("by \(author)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button("Update") {
                        showingUpdatePage = true
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Free Online Versions Section
            if book.hasFreeVersion {
                Section {
                    ForEach(book.freeBookSources) { source in
                        Link(destination: source.url) {
                            Label {
                                VStack(alignment: .leading) {
                                    Text("Read on \(source.name)")
                                        .font(.body)
                                    Text(source.url.host ?? "")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: iconForSource(source.type))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                } header: {
                    Label("Free Online Version", systemImage: "book.closed.fill")
                } footer: {
                    Text("This book is available to read for free online.")
                }
            }

            // Audiobook Section
            if book.hasAudiobook, let urlString = book.librivoxURL, let url = URL(string: urlString) {
                Section {
                    Link(destination: url) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Listen on LibriVox")
                                    .font(.body)
                                if let duration = book.librivoxDuration {
                                    Text("Duration: \(duration)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("librivox.org")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } icon: {
                            Image(systemName: "headphones")
                                .foregroundStyle(.purple)
                        }
                    }
                } header: {
                    Label("Free Audiobook", systemImage: "headphones")
                } footer: {
                    Text("Free audiobook narrated by volunteers.")
                }
            }

            // Downloaded Content Section
            if book.internetArchiveId != nil {
                Section {
                    if book.hasDownloadedContent {
                        // Show chapter progress
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Chapter \((book.currentChapter ?? 0) + 1) of \(book.downloadedChapterCount ?? 0)")
                                    .font(.headline)
                                if let words = book.downloadedWordCount {
                                    Text("\(words.formatted()) words total")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            Button("Update") {
                                showingUpdateChapter = true
                            }
                            .buttonStyle(.bordered)
                        }

                        // Show chapter list
                        if let content = book.epubContent {
                            DisclosureGroup("Chapters") {
                                ForEach(content.chapters.sorted { $0.orderIndex < $1.orderIndex }) { chapter in
                                    HStack {
                                        Text(chapter.title)
                                            .font(.subheadline)
                                        Spacer()
                                        if chapter.orderIndex <= (book.currentChapter ?? 0) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.green)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        // Check text availability and show download button
                        if hasTextVersion == nil {
                            // Still checking
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking availability...")
                                    .foregroundStyle(.secondary)
                            }
                        } else if hasTextVersion == true {
                            // Download button
                            Button {
                                Task { await downloadBook() }
                            } label: {
                                HStack {
                                    if isDownloading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Downloading...")
                                    } else {
                                        Label("Download for Offline Reading", systemImage: "arrow.down.circle")
                                    }
                                }
                            }
                            .disabled(isDownloading)
                        } else {
                            // No text version available - show helpful alternative
                            VStack(alignment: .leading, spacing: 8) {
                                Label("No downloadable text", systemImage: "xmark.circle")
                                    .foregroundStyle(.orange)

                                if book.internetArchiveURL != nil {
                                    Link(destination: URL(string: book.internetArchiveURL!)!) {
                                        Label("Read Online Instead", systemImage: "safari")
                                            .font(.subheadline)
                                    }
                                }
                            }
                        }

                        if let error = downloadError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                } header: {
                    Label("Downloaded Book", systemImage: "internaldrive")
                } footer: {
                    if book.hasDownloadedContent {
                        Text("Book text downloaded. Character queries use this content up to your current chapter.")
                    } else if hasTextVersion == false {
                        Text("This book is available to read online but doesn't have a downloadable text file. You can scan pages manually instead.")
                    } else {
                        Text("Download the book text to enable character queries without scanning.")
                    }
                }
            }

            // Character Query Section
            Section {
                Button(action: { showingCharacterQuery = true }) {
                    Label("Ask About a Character", systemImage: "person.fill.questionmark")
                }
                .disabled(!canQueryCharacters)
            } footer: {
                if canQueryCharacters {
                    if book.hasDownloadedContent {
                        Text("Using downloaded book text up to Chapter \((book.currentChapter ?? 0) + 1).")
                    } else {
                        Text("Get spoiler-free information about any character based on what you've read so far.")
                    }
                } else {
                    Text("Download the book or scan some pages first to enable character queries.")
                }
            }

            // Passages Section
            Section("Passages (\(book.passages.count))") {
                if book.passages.isEmpty {
                    Text("No passages scanned yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(book.passages.sorted { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }) { passage in
                        NavigationLink(destination: PassageDetailView(passage: passage)) {
                            PassageRowView(passage: passage)
                        }
                    }
                    .onDelete(perform: deletePassages)
                }
            }
        }
        .navigationTitle(book.title)
        .sheet(isPresented: $showingCharacterQuery) {
            CharacterQueryView(book: book)
        }
        .sheet(isPresented: $showingUpdatePage) {
            UpdatePageView(book: book)
        }
        .sheet(isPresented: $showingUpdateChapter) {
            UpdateChapterView(book: book)
        }
        .onAppear {
            // Check text availability for download section
            if book.internetArchiveId != nil && !book.hasDownloadedContent && hasTextVersion == nil {
                Task { await checkTextAvailability() }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        Task { await exportBook() }
                    } label: {
                        Label("Export to iCloud", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                } label: {
                    if isExporting {
                        ProgressView()
                    } else {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .alert("Exported", isPresented: $showingExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Book exported to iCloud Documents.")
        }
        .alert("Export Error", isPresented: .constant(exportError != nil)) {
            Button("OK") { exportError = nil }
        } message: {
            if let error = exportError {
                Text(error)
            }
        }
    }

    /// Export this book to iCloud Documents
    private func exportBook() async {
        isExporting = true
        defer { isExporting = false }

        do {
            try ImportExportService.shared.exportBookToICloud(book)
            showingExportSuccess = true
        } catch {
            exportError = error.localizedDescription
        }
    }

    /// Check if a downloadable text version exists
    private func checkTextAvailability() async {
        guard let iaId = book.internetArchiveId else { return }
        let available = await EPUBService.shared.hasTextVersion(internetArchiveId: iaId)
        await MainActor.run {
            hasTextVersion = available
        }
    }

    /// Whether character queries are available
    private var canQueryCharacters: Bool {
        book.hasDownloadedContent || !book.passages.isEmpty
    }

    /// Download book text from Internet Archive
    private func downloadBook() async {
        guard let iaId = book.internetArchiveId else { return }

        isDownloading = true
        downloadError = nil

        do {
            let content = try await EPUBService.shared.downloadAndParse(internetArchiveId: iaId)
            await MainActor.run {
                book.setEPUBContent(content)
                isDownloading = false
            }
        } catch {
            await MainActor.run {
                downloadError = error.localizedDescription
                isDownloading = false
            }
        }
    }

    private func deletePassages(at offsets: IndexSet) {
        let sortedPassages = book.passages.sorted { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }
        for index in offsets {
            modelContext.delete(sortedPassages[index])
        }
    }

    private func iconForSource(_ type: FreeBookSource.SourceType) -> String {
        switch type {
        case .openLibrary:
            return "building.columns"
        case .internetArchive:
            return "archivebox"
        case .projectGutenberg:
            return "books.vertical"
        case .standardEbooks:
            return "book"
        }
    }
}

struct PassageRowView: View {
    let passage: Passage

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pageNumber = passage.pageNumber {
                Text("Page \(pageNumber)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(passage.textPreview)
                .font(.subheadline)
                .lineLimit(2)

            if passage.aiSummary != nil {
                Label("Has AI summary", systemImage: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }
}

struct UpdatePageView: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss

    @State private var pageText = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Current Page") {
                    TextField("Page number", text: $pageText)
                        .keyboardType(.numberPad)
                        .onAppear {
                            pageText = String(book.currentPage)
                        }
                }

                if let total = book.totalPages {
                    Section {
                        Text("Book has \(total) pages total")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Update Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let page = Int(pageText) {
                            book.currentPage = page
                            book.dateLastRead = Date()
                            book.needsSync = true

                            // Auto-export to iCloud
                            Task {
                                try? ImportExportService.shared.exportBookToICloud(book)
                            }
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

struct UpdateChapterView: View {
    @Bindable var book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if let content = book.epubContent {
                    ForEach(content.chapters.sorted { $0.orderIndex < $1.orderIndex }) { chapter in
                        Button {
                            book.currentChapter = chapter.orderIndex
                            book.dateLastRead = Date()
                            book.needsSync = true

                            // Auto-export to iCloud
                            Task {
                                try? ImportExportService.shared.exportBookToICloud(book)
                            }

                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(chapter.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("\(chapter.wordCount.formatted()) words")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if chapter.orderIndex == (book.currentChapter ?? 0) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                } else if chapter.orderIndex < (book.currentChapter ?? 0) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Text("No chapters available")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Select Current Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald"))
    }
    .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
