//
//  LibraryView.swift
//  ReadingCompanion
//
//  View for browsing and managing the book library.
//

import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateAdded, order: .reverse) private var books: [Book]

    @State private var showingAddBook = false
    @State private var showingFreeBookSearch = false
    @State private var searchText = ""

    var filteredBooks: [Book] {
        if searchText.isEmpty {
            return books
        }
        return books.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            (book.author?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if books.isEmpty {
                    emptyStateView
                } else {
                    bookListView
                }
            }
            .navigationTitle("Library")
            .searchable(text: $searchText, prompt: "Search books")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button(action: { showingFreeBookSearch = true }) {
                            Label("Find Free Books", systemImage: "globe")
                        }
                        Button(action: { showingAddBook = true }) {
                            Label("Add Book Manually", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
            .sheet(isPresented: $showingFreeBookSearch) {
                FreeBookSearchView()
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Books Yet", systemImage: "books.vertical")
        } description: {
            Text("Add a book to start tracking your reading and unlock AI-powered character insights.")
        } actions: {
            VStack(spacing: 12) {
                Button(action: { showingFreeBookSearch = true }) {
                    Label("Find Free Books", systemImage: "globe")
                }
                .buttonStyle(.borderedProminent)

                Button(action: { showingAddBook = true }) {
                    Label("Add Manually", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var bookListView: some View {
        List {
            ForEach(filteredBooks) { book in
                NavigationLink(destination: BookDetailView(book: book)) {
                    BookRowView(book: book)
                }
            }
            .onDelete(perform: deleteBooks)
        }
    }

    private func deleteBooks(at offsets: IndexSet) {
        for index in offsets {
            let book = filteredBooks[index]
            // Delete exported file (CRUD completeness)
            ImportExportService.shared.deleteExportedFile(for: book)
            // Remove from Spotlight index
            SpotlightService.shared.removeBook(book)
            modelContext.delete(book)
        }
    }
}

struct BookRowView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title row with status badges
            HStack(alignment: .center, spacing: 8) {
                Text(book.title)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                // Status badges
                HStack(spacing: 4) {
                    if book.hasDownloadedContent {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else if book.internetArchiveId != nil {
                        Image(systemName: "arrow.down.circle")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if book.hasAudiobook {
                        Image(systemName: "headphones")
                            .font(.caption)
                            .foregroundStyle(.purple)
                    }
                }
            }

            if let author = book.author, !author.isEmpty {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Progress bar and stats
            HStack(spacing: 12) {
                // Visual progress indicator
                if let total = book.totalPages, total > 0 {
                    ProgressView(value: Double(book.currentPage), total: Double(total))
                        .tint(progressColor)
                        .frame(width: 60)
                }

                Text(book.progressDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if book.passages.count > 0 {
                    Label("\(book.passages.count)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        guard let total = book.totalPages, total > 0 else { return .blue }
        let progress = Double(book.currentPage) / Double(total)
        if progress >= 1.0 { return .green }
        if progress >= 0.5 { return .blue }
        return .orange
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
