//
//  ScanView.swift
//  ReadingCompanion
//
//  Camera view for scanning book pages with OCR and AI explanation.
//

import SwiftUI
import SwiftData
import AVFoundation

struct ScanView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Book.dateLastRead, order: .reverse) private var books: [Book]

    @State private var capturedImage: UIImage?
    @State private var ocrText = ""
    @State private var aiExplanation = ""
    @State private var isProcessingOCR = false
    @State private var isLoadingAI = false
    @State private var errorMessage: String?
    @State private var selectedBook: Book?
    @State private var pageNumber = ""
    @State private var showingCamera = false
    @State private var showingSaveConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Camera/Image Section
                    cameraSection

                    // OCR Result Section
                    if !ocrText.isEmpty {
                        ocrResultSection
                    }

                    // AI Explanation Section
                    if !aiExplanation.isEmpty {
                        aiExplanationSection
                    }

                    // Error Message
                    if let error = errorMessage {
                        errorSection(error)
                    }
                }
                .padding()
            }
            .navigationTitle("Scan Page")
            .sheet(isPresented: $showingCamera) {
                CameraView(capturedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newImage in
                if newImage != nil {
                    Task {
                        await processImage()
                    }
                }
            }
            .alert("Save Passage", isPresented: $showingSaveConfirmation) {
                Button("Save") {
                    savePassage()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Save this passage to your library?")
            }
        }
    }

    private var cameraSection: some View {
        VStack(spacing: 12) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .cornerRadius(12)

                Button("Scan Another Page") {
                    resetState()
                    showingCamera = true
                }
                .buttonStyle(.bordered)
            } else {
                Button(action: { showingCamera = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.viewfinder")
                            .font(.system(size: 60))
                        Text("Tap to Scan a Page")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var ocrResultSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Extracted Text", systemImage: "doc.text")
                    .font(.headline)

                Spacer()

                if isProcessingOCR {
                    ProgressView()
                }
            }

            Text(ocrText)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(8)

            // Book association
            VStack(alignment: .leading, spacing: 8) {
                Text("Associate with book (optional):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Book", selection: $selectedBook) {
                    Text("None").tag(nil as Book?)
                    ForEach(books) { book in
                        Text(book.title).tag(book as Book?)
                    }
                }
                .pickerStyle(.menu)

                if selectedBook != nil {
                    TextField("Page number", text: $pageNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                }
            }

            // Actions
            HStack {
                Button("Get AI Explanation") {
                    Task {
                        await getExplanation()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoadingAI || !KeychainService.shared.hasAPIKey)

                Button("Save Passage") {
                    showingSaveConfirmation = true
                }
                .buttonStyle(.bordered)
                .disabled(selectedBook == nil)
            }
        }
    }

    private var aiExplanationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Explanation", systemImage: "sparkles")
                    .font(.headline)

                Spacer()

                if isLoadingAI {
                    ProgressView()
                }
            }

            Text(aiExplanation)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
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

    private func processImage() async {
        guard let image = capturedImage else { return }

        isProcessingOCR = true
        errorMessage = nil

        do {
            let result = try await OCRService.shared.recognizeText(from: image)
            await MainActor.run {
                ocrText = result.text
                isProcessingOCR = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isProcessingOCR = false
            }
        }
    }

    private func getExplanation() async {
        guard !ocrText.isEmpty else { return }

        isLoadingAI = true
        errorMessage = nil

        do {
            let explanation = try await ClaudeService.shared.explainPassage(
                ocrText,
                bookTitle: selectedBook?.title
            )
            await MainActor.run {
                aiExplanation = explanation
                isLoadingAI = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoadingAI = false
            }
        }
    }

    private func savePassage() {
        guard let book = selectedBook else { return }

        let passage = Passage(
            text: ocrText,
            pageNumber: Int(pageNumber),
            aiSummary: aiExplanation.isEmpty ? nil : aiExplanation,
            book: book
        )

        modelContext.insert(passage)

        // Update book's current page if provided
        if let page = Int(pageNumber), page > book.currentPage {
            book.currentPage = page
            book.dateLastRead = Date()
        }

        // Reset for next scan
        resetState()
    }

    private func resetState() {
        capturedImage = nil
        ocrText = ""
        aiExplanation = ""
        pageNumber = ""
        errorMessage = nil
    }
}

#Preview {
    ScanView()
        .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
