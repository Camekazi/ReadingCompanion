//
//  ReadingCompanionApp.swift
//  ReadingCompanion
//
//  An AI-powered reading companion using Claude for passage explanations
//  and spoiler-free character queries.
//

import SwiftUI
import SwiftData
import CoreSpotlight

@main
struct ReadingCompanionApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            Passage.self,
            ReadingSession.self,
            VocabularyWord.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    /// Book ID selected from Spotlight search
    @State private var selectedBookId: UUID?

    var body: some Scene {
        WindowGroup {
            ContentView(selectedBookId: $selectedBookId)
                .onContinueUserActivity(CSSearchableItemActionType, perform: handleSpotlightActivity)
                .onAppear {
                    // Index all books on app launch
                    indexAllBooks()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Handle tap on Spotlight search result
    private func handleSpotlightActivity(_ userActivity: NSUserActivity) {
        guard let identifier = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
              let uuid = UUID(uuidString: identifier) else {
            return
        }

        selectedBookId = uuid
    }

    /// Index all books for Spotlight on app launch
    private func indexAllBooks() {
        let context = ModelContext(sharedModelContainer)
        let descriptor = FetchDescriptor<Book>()

        do {
            let books = try context.fetch(descriptor)
            SpotlightService.shared.indexBooks(books)
        } catch {
            print("Failed to fetch books for Spotlight indexing: \(error)")
        }
    }
}
