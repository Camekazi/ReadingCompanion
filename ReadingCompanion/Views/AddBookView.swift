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

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Details") {
                    TextField("Title", text: $title)
                        .textContentType(.none)
                        .autocorrectionDisabled()

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

    private func addBook() {
        let book = Book(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            author: author.isEmpty ? nil : author.trimmingCharacters(in: .whitespacesAndNewlines),
            isbn: isbn.isEmpty ? nil : isbn,
            totalPages: Int(totalPages)
        )

        modelContext.insert(book)
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
