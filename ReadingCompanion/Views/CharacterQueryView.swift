//
//  CharacterQueryView.swift
//  ReadingCompanion
//
//  View for querying information about characters with spoiler protection.
//

import SwiftUI

struct CharacterQueryView: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss

    @State private var characterName = ""
    @State private var response = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Info section
                    infoSection

                    // Query input
                    querySection

                    // Response
                    if !response.isEmpty {
                        responseSection
                    }

                    // Error
                    if let error = errorMessage {
                        errorSection(error)
                    }
                }
                .padding()
            }
            .navigationTitle("Character Query")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(.green)
                Text("Spoiler Protection Active")
                    .font(.headline)
            }

            Text("Responses are based only on the \(book.passages.count) passages you've scanned up to page \(book.currentPage). No information beyond your current reading position will be revealed.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    private var querySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Who would you like to know about?")
                .font(.headline)

            TextField("Character name", text: $characterName)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Button(action: queryCharacter) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isLoading ? "Thinking..." : "Ask Claude")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(characterName.isEmpty || isLoading || !KeychainService.shared.hasAPIKey)

            if !KeychainService.shared.hasAPIKey {
                Text("Please add your API key in Settings first.")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(.blue)
                Text("About \(characterName)")
                    .font(.headline)
            }

            Text(response)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
        }
    }

    private func errorSection(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
            Text(message)
        }
        .foregroundStyle(.red)
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }

    private func queryCharacter() {
        guard !characterName.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task {
            do {
                // Get passages up to current page
                let passageTexts = book.passagesUpToCurrentPage.map { $0.text }

                let result = try await ClaudeService.shared.queryCharacter(
                    name: characterName,
                    bookTitle: book.title,
                    currentPage: book.currentPage,
                    passages: passageTexts
                )

                await MainActor.run {
                    response = result
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    let book = Book(title: "The Great Gatsby", author: "F. Scott Fitzgerald", currentPage: 50)
    return CharacterQueryView(book: book)
}
