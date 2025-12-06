//
//  ReadingCompanionApp.swift
//  ReadingCompanion
//
//  An AI-powered reading companion using Claude for passage explanations
//  and spoiler-free character queries.
//

import SwiftUI
import SwiftData

@main
struct ReadingCompanionApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Book.self,
            Passage.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
