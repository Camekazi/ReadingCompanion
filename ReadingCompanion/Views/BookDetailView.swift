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

            // Character Query Section
            Section {
                Button(action: { showingCharacterQuery = true }) {
                    Label("Ask About a Character", systemImage: "person.fill.questionmark")
                }
                .disabled(book.passages.isEmpty)
            } footer: {
                if book.passages.isEmpty {
                    Text("Scan some pages first to enable character queries.")
                } else {
                    Text("Get spoiler-free information about any character based on what you've read so far.")
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
    }

    private func deletePassages(at offsets: IndexSet) {
        let sortedPassages = book.passages.sorted { ($0.pageNumber ?? 0) < ($1.pageNumber ?? 0) }
        for index in offsets {
            modelContext.delete(sortedPassages[index])
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
                        }
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald"))
    }
    .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
