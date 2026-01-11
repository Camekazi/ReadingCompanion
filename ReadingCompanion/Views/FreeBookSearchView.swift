//
//  FreeBookSearchView.swift
//  ReadingCompanion
//
//  View for searching and discovering free books from Open Library.
//

import SwiftUI
import SwiftData

struct FreeBookSearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery = ""
    @State private var searchResults: [BookMetadata] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var addedBookIds: Set<String> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Results
                if isSearching {
                    loadingView
                } else if searchResults.isEmpty && hasSearched {
                    emptyResultsView
                } else if searchResults.isEmpty {
                    welcomeView
                } else {
                    resultsList
                }
            }
            .navigationTitle("Discover Free Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Search for free books...", text: $searchQuery)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onSubmit {
                    Task { await performSearch() }
                }

            if !searchQuery.isEmpty {
                Button(action: { searchQuery = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding()
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Searching Open Library...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Search for Free Books")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Find public domain classics from Open Library.\nBooks can be read online; some also have\ndownloadable text for offline character queries.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)

            // Suggested searches
            VStack(alignment: .leading, spacing: 8) {
                Text("Try searching for:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top)

                ForEach(suggestedSearches, id: \.self) { suggestion in
                    Button(action: {
                        searchQuery = suggestion
                        Task { await performSearch() }
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(suggestion)
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var suggestedSearches: [String] {
        ["Pride and Prejudice", "Sherlock Holmes", "Moby Dick", "Frankenstein", "Dracula"]
    }

    private var emptyResultsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("No Free Books Found")
                .font(.title3)
                .fontWeight(.semibold)

            Text("Try a different search term.\nPublic domain books work best!")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsList: some View {
        List(searchResults, id: \.title) { book in
            FreeBookRow(
                book: book,
                isAdded: addedBookIds.contains(book.internetArchiveIds.first ?? book.title),
                onAdd: { addBookToLibrary(book) }
            )
        }
        .listStyle(.plain)
    }

    private func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        isSearching = true
        hasSearched = true

        do {
            searchResults = try await OpenLibraryService.shared.searchFreeBooks(query: searchQuery)
        } catch {
            print("Search error: \(error)")
            searchResults = []
        }

        isSearching = false
    }

    private func addBookToLibrary(_ metadata: BookMetadata) {
        // Create new book with free book data pre-populated
        let book = Book(
            title: metadata.title,
            author: metadata.author,
            totalPages: metadata.pageCount
        )

        // Set up Internet Archive URL for downloading
        if let iaId = metadata.internetArchiveIds.first {
            book.internetArchiveURL = "https://archive.org/details/\(iaId)"
        }

        // Set Open Library URL if available
        if let workKey = metadata.workKey {
            book.openLibraryURL = "https://openlibrary.org\(workKey)"
        }

        modelContext.insert(book)

        // Index in Spotlight for iOS search
        SpotlightService.shared.indexBook(book)

        // Track that we added this book
        let bookId = metadata.internetArchiveIds.first ?? metadata.title
        addedBookIds.insert(bookId)
    }
}

struct FreeBookRow: View {
    let book: BookMetadata
    let isAdded: Bool
    let onAdd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Cover image
            AsyncImage(url: book.coverURL) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay {
                        Image(systemName: "book.closed")
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 50, height: 70)
            .cornerRadius(4)

            // Book info
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                if let author = book.author {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if let year = book.publishYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !book.internetArchiveIds.isEmpty {
                        Label("Internet Archive", systemImage: "archivebox")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }

            Spacer()

            // Add button
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title2)
            } else {
                Button(action: onAdd) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FreeBookSearchView()
        .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
