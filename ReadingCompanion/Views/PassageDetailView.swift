//
//  PassageDetailView.swift
//  ReadingCompanion
//
//  Detail view for a single passage with AI summary.
//

import SwiftUI
import SwiftData

struct PassageDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var passage: Passage
    @State private var isLoadingAI = false
    @State private var errorMessage: String?
    @State private var extractedWordCount = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Metadata
                if let pageNumber = passage.pageNumber {
                    HStack {
                        Label("Page \(pageNumber)", systemImage: "book")
                        Spacer()
                        Text(passage.dateCreated.formatted(date: .abbreviated, time: .shortened))
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline)
                }

                // Original text
                VStack(alignment: .leading, spacing: 8) {
                    Text("Passage")
                        .font(.headline)

                    Text(passage.text)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }

                // AI Summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("AI Explanation")
                            .font(.headline)

                        Spacer()

                        if isLoadingAI {
                            ProgressView()
                        } else if passage.aiSummary == nil {
                            Button("Generate") {
                                Task { await generateSummary() }
                            }
                            .buttonStyle(.bordered)
                            .disabled(!KeychainService.shared.hasAPIKey)
                        } else {
                            Button("Regenerate") {
                                Task { await generateSummary() }
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    if let summary = passage.aiSummary {
                        Text(summary)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                    } else if !KeychainService.shared.hasAPIKey {
                        Text("Add your API key in Settings to generate explanations.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        Text("Tap 'Generate' to get an AI explanation of this passage.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }

                    // Show vocabulary extraction result
                    if extractedWordCount > 0 {
                        HStack {
                            Image(systemName: "text.book.closed")
                                .foregroundStyle(.green)
                            Text("\(extractedWordCount) vocabulary word\(extractedWordCount == 1 ? "" : "s") saved")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Vocabulary words for this passage
                if !passage.vocabularyWords.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vocabulary")
                            .font(.headline)

                        ForEach(passage.vocabularyWords, id: \.id) { word in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(word.word)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    if let pos = word.formattedPartOfSpeech {
                                        Text(pos)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(word.definition)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }

                // User notes (future feature placeholder)
                if let notes = passage.userNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Notes")
                            .font(.headline)

                        Text(notes)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.1))
                            .cornerRadius(8)
                    }
                }

                // Error message
                if let error = errorMessage {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                        Text(error)
                    }
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }

                Spacer()
            }
            .padding()
        }
        .navigationTitle("Passage")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func generateSummary() async {
        isLoadingAI = true
        errorMessage = nil
        extractedWordCount = 0

        do {
            let result = try await ClaudeService.shared.explainPassageWithVocabulary(
                passage.text,
                bookTitle: passage.book?.title
            )

            await MainActor.run {
                passage.aiSummary = result.explanation

                // Save vocabulary words
                for extracted in result.vocabulary {
                    let vocabWord = VocabularyWord(
                        word: extracted.word,
                        definition: extracted.definition,
                        context: extracted.context,
                        partOfSpeech: extracted.partOfSpeech,
                        book: passage.book,
                        passage: passage
                    )
                    modelContext.insert(vocabWord)
                }

                extractedWordCount = result.vocabulary.count
                isLoadingAI = false

                // Auto-export book to iCloud
                if let book = passage.book {
                    book.needsSync = true
                    Task {
                        try? ImportExportService.shared.exportBookToICloud(book)
                    }
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoadingAI = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PassageDetailView(passage: Passage(
            text: "In my younger and more vulnerable years my father gave me some advice that I've been turning over in my mind ever since.",
            pageNumber: 1
        ))
    }
    .modelContainer(for: [Book.self, Passage.self, ReadingSession.self, VocabularyWord.self], inMemory: true)
}
