//
//  VocabularyListView.swift
//  ReadingCompanion
//
//  View for browsing and managing vocabulary words learned from reading.
//

import SwiftUI
import SwiftData

struct VocabularyListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \VocabularyWord.dateAdded, order: .reverse) private var words: [VocabularyWord]

    @State private var searchText = ""
    @State private var showMasteredOnly = false
    @State private var selectedBook: Book?

    private var filteredWords: [VocabularyWord] {
        var result = words

        if showMasteredOnly {
            result = result.filter { !$0.isMastered }
        }

        if let book = selectedBook {
            result = result.filter { $0.book?.id == book.id }
        }

        if !searchText.isEmpty {
            result = result.filter { word in
                word.word.localizedCaseInsensitiveContains(searchText) ||
                word.definition.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    private var uniqueBooks: [Book] {
        let bookSet = Set(words.compactMap { $0.book })
        return Array(bookSet).sorted { $0.title < $1.title }
    }

    var body: some View {
        Group {
            if words.isEmpty {
                emptyStateView
            } else {
                wordListView
            }
        }
        .navigationTitle("Vocabulary")
        .searchable(text: $searchText, prompt: "Search words")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Toggle("Show Unmastered Only", isOn: $showMasteredOnly)

                    Divider()

                    Menu("Filter by Book") {
                        Button("All Books") {
                            selectedBook = nil
                        }
                        Divider()
                        ForEach(uniqueBooks, id: \.id) { book in
                            Button(book.title) {
                                selectedBook = book
                            }
                        }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }

    private var emptyStateView: some View {
        ContentUnavailableView {
            Label("No Words Yet", systemImage: "text.book.closed")
        } description: {
            Text("Vocabulary words will appear here when Claude explains passages with interesting terms.")
        }
    }

    private var wordListView: some View {
        List {
            ForEach(filteredWords, id: \.id) { word in
                VocabularyRowView(word: word)
                    .swipeActions(edge: .leading) {
                        Button {
                            toggleMastered(word)
                        } label: {
                            Label(
                                word.isMastered ? "Unmaster" : "Mastered",
                                systemImage: word.isMastered ? "arrow.uturn.backward" : "checkmark.circle"
                            )
                        }
                        .tint(word.isMastered ? .orange : .green)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            deleteWord(word)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func toggleMastered(_ word: VocabularyWord) {
        word.isMastered.toggle()
    }

    private func deleteWord(_ word: VocabularyWord) {
        modelContext.delete(word)
    }
}

// MARK: - Vocabulary Row

struct VocabularyRowView: View {
    let word: VocabularyWord

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(word.word)
                    .font(.headline)

                if let pos = word.formattedPartOfSpeech {
                    Text(pos)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if word.isMastered {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                }
            }

            Text(word.definition)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let context = word.context, !context.isEmpty {
                Text("\"\(context)\"")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .italic()
            }

            if let book = word.book {
                HStack(spacing: 4) {
                    Image(systemName: "book.closed")
                        .font(.caption2)
                    Text(book.title)
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        VocabularyListView()
    }
    .modelContainer(for: [Book.self, Passage.self, ReadingSession.self, VocabularyWord.self], inMemory: true)
}
