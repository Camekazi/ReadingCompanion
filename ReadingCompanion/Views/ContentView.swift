//
//  ContentView.swift
//  ReadingCompanion
//
//  Main navigation view with tab bar for Library, Statistics, Scan, and Settings.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]
    @Binding var selectedBookId: UUID?
    @State private var selectedTab = 0
    @State private var showingAPIKeyAlert = false
    @State private var showingImportAlert = false
    @State private var importedPassageCount = 0
    @State private var navigateToBook: Book?

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)

            StatisticsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                .tag(1)

            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(3)
        }
        .onAppear {
            checkAPIKey()
            importPendingPassages()
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("Go to Settings") {
                selectedTab = 3
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Please add your Claude API key in Settings to enable AI features.")
        }
        .alert("Passages Imported", isPresented: $showingImportAlert) {
            Button("View Library") {
                selectedTab = 0
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("\(importedPassageCount) passage\(importedPassageCount == 1 ? "" : "s") imported from Share Extension.")
        }
        .onChange(of: selectedBookId) { _, newId in
            // Handle Spotlight search result tap
            if let bookId = newId,
               let book = books.first(where: { $0.id == bookId }) {
                navigateToBook = book
                selectedTab = 0  // Switch to Library tab
                selectedBookId = nil  // Clear to allow re-selection
            }
        }
        .sheet(item: $navigateToBook) { book in
            NavigationStack {
                BookDetailView(book: book)
            }
        }
    }

    private func importPendingPassages() {
        Task { @MainActor in
            let count = PendingPassageService.shared.importPendingPassages(into: modelContext)
            if count > 0 {
                importedPassageCount = count
                showingImportAlert = true
            }
        }
    }

    private func checkAPIKey() {
        if !KeychainService.shared.hasAPIKey {
            // Delay to let the view appear first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                showingAPIKeyAlert = true
            }
        }
    }
}

#Preview {
    ContentView(selectedBookId: .constant(nil))
        .modelContainer(for: [Book.self, Passage.self, ReadingSession.self, VocabularyWord.self], inMemory: true)
}
