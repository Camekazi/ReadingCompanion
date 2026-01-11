//
//  AddBookView.swift
//  ReadingCompanion
//
//  Form for adding a new book to the library.
//

import SwiftUI
import SwiftData

struct AddBookView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var author = ""
    @State private var isbn = ""
    @State private var totalPages = ""
    @State private var isLoadingMetadata = false
    @State private var showingScanner = false

    // Search autocomplete state
    @State private var searchResults: [BookMetadata] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    @State private var showSearchResults = false

    // Selected book's free version URLs
    @State private var selectedOpenLibraryURL: String?
    @State private var selectedInternetArchiveURL: String?

    // Audiobook state
    @State private var selectedLibrivoxURL: String?
    @State private var selectedLibrivoxId: String?
    @State private var selectedLibrivoxDuration: String?
    @State private var isCheckingAudiobook = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Details") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                        .onChange(of: title) { _, newValue in
                            searchBooks(query: newValue)
                        }

                    // Search results dropdown
                    if showSearchResults && !searchResults.isEmpty {
                        ForEach(searchResults, id: \.title) { result in
                            Button {
                                selectSearchResult(result)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                        if let author = result.author {
                                            Text(author)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        if let year = result.publishYear {
                                            Text("Published: \(String(year))")
                                                .font(.caption2)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }

                                    Spacer()

                                    // Free book indicator
                                    if result.hasFreeVersion {
                                        Label("Free", systemImage: "book.closed.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if isSearching {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Searching...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    TextField("Author", text: $author)
                        .textContentType(.name)

                    TextField("Total Pages (optional)", text: $totalPages)
                        .keyboardType(.numberPad)
                }

                Section("ISBN (Optional)") {
                    HStack {
                        TextField("ISBN", text: $isbn)
                            .keyboardType(.numberPad)

                        Button(action: { showingScanner = true }) {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }

                    if !isbn.isEmpty {
                        Button("Fetch Metadata") {
                            Task {
                                await fetchMetadata()
                            }
                        }
                        .disabled(isLoadingMetadata)
                    }
                }

                // Show detected free versions after selecting a book
                if selectedOpenLibraryURL != nil || selectedInternetArchiveURL != nil || selectedLibrivoxURL != nil || isCheckingAudiobook {
                    Section("Available Free Versions") {
                        if selectedInternetArchiveURL != nil {
                            Label("Free ebook available", systemImage: "book.closed.fill")
                                .foregroundStyle(.green)
                        }
                        if selectedOpenLibraryURL != nil {
                            Label("Open Library version", systemImage: "building.columns")
                                .foregroundStyle(.green)
                        }
                        if isCheckingAudiobook {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Checking for audiobook...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else if selectedLibrivoxURL != nil {
                            HStack {
                                Label("Audiobook available", systemImage: "headphones")
                                    .foregroundStyle(.purple)
                                if let duration = selectedLibrivoxDuration {
                                    Spacer()
                                    Text(duration)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }

                if isLoadingMetadata {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Fetching book info...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Add Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addBook()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .sheet(isPresented: $showingScanner) {
                ISBNScannerView(isbn: $isbn)
            }
        }
    }

    // MARK: - Search Functions

    private func searchBooks(query: String) {
        // Cancel previous search
        searchTask?.cancel()

        // Clear results if query is too short
        guard query.count >= 3 else {
            searchResults = []
            showSearchResults = false
            isSearching = false
            return
        }

        // Debounce: wait 300ms before searching
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))

            guard !Task.isCancelled else { return }

            await MainActor.run { isSearching = true }

            do {
                let results = try await OpenLibraryService.shared.searchBooks(title: query)

                guard !Task.isCancelled else { return }

                await MainActor.run {
                    searchResults = results
                    showSearchResults = true
                    isSearching = false
                }
            } catch {
                await MainActor.run {
                    isSearching = false
                }
            }
        }
    }

    private func selectSearchResult(_ result: BookMetadata) {
        title = result.title
        author = result.author ?? ""
        if let pages = result.pageCount {
            totalPages = String(pages)
        }

        // Store free book URLs if available
        if let workKey = result.workKey, result.hasFullText {
            selectedOpenLibraryURL = "https://openlibrary.org\(workKey)"
        } else {
            selectedOpenLibraryURL = nil
        }

        if let firstIaId = result.internetArchiveIds.first {
            selectedInternetArchiveURL = "https://archive.org/details/\(firstIaId)"
        } else {
            selectedInternetArchiveURL = nil
        }

        // Hide search results after selection
        searchResults = []
        showSearchResults = false

        // Check LibriVox for audiobook (async, non-blocking)
        checkForAudiobook(title: result.title, author: result.author)
    }

    private func checkForAudiobook(title: String, author: String?) {
        isCheckingAudiobook = true

        Task {
            defer {
                Task { @MainActor in
                    isCheckingAudiobook = false
                }
            }

            if let audiobook = try? await LibriVoxService.shared.searchAudiobook(title: title, author: author) {
                await MainActor.run {
                    selectedLibrivoxURL = audiobook.url.absoluteString
                    selectedLibrivoxId = audiobook.id
                    selectedLibrivoxDuration = audiobook.totalTime
                }
            } else {
                await MainActor.run {
                    selectedLibrivoxURL = nil
                    selectedLibrivoxId = nil
                    selectedLibrivoxDuration = nil
                }
            }
        }
    }

    private func addBook() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.isEmpty ? nil : author.trimmingCharacters(in: .whitespacesAndNewlines),
            isbn: isbn.isEmpty ? nil : isbn,
            totalPages: Int(totalPages),
            openLibraryURL: selectedOpenLibraryURL,
            internetArchiveURL: selectedInternetArchiveURL,
            librivoxURL: selectedLibrivoxURL,
            librivoxId: selectedLibrivoxId,
            librivoxDuration: selectedLibrivoxDuration
        )

        modelContext.insert(book)

        // Index in Spotlight for iOS search
        SpotlightService.shared.indexBook(book)

        dismiss()
    }

    private func fetchMetadata() async {
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }

        do {
            if let metadata = try await OpenLibraryService.shared.fetchBook(isbn: isbn) {
                await MainActor.run {
                    if title.isEmpty { title = metadata.title }
                    if author.isEmpty { author = metadata.author ?? "" }
                    if totalPages.isEmpty, let pages = metadata.pageCount {
                        totalPages = String(pages)
                    }
                }
            }
        } catch {
            print("Failed to fetch metadata: \(error)")
        }
    }
}

#Preview {
    AddBookView()
        .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
