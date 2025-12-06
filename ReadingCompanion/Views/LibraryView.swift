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
                    Button(action: { showingAddBook = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddBook) {
                AddBookView()
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Books Yet", systemImage: "books.vertical")
        } description: {
            Text("Add your first book to start tracking your reading.")
        } actions: {
            Button("Add Book") {
                showingAddBook = true
            }
            .buttonStyle(.borderedProminent)
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
            modelContext.delete(filteredBooks[index])
        }
    }
}

struct BookRowView: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(book.title)
                .font(.headline)

            if let author = book.author, !author.isEmpty {
                Text(author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(book.progressDescription)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                Text("\(book.passages.count) passages")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    LibraryView()
        .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
