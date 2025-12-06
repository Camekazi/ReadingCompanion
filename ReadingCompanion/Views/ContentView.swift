//
//  ContentView.swift
//  ReadingCompanion
//
//  Main navigation view with tab bar for Library, Scan, and Settings.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var showingAPIKeyAlert = false

    var body: some View {
        TabView(selection: $selectedTab) {
            LibraryView()
                .tabItem {
                    Label("Library", systemImage: "books.vertical")
                }
                .tag(0)

            ScanView()
                .tabItem {
                    Label("Scan", systemImage: "camera.viewfinder")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(2)
        }
        .onAppear {
            checkAPIKey()
        }
        .alert("API Key Required", isPresented: $showingAPIKeyAlert) {
            Button("Go to Settings") {
                selectedTab = 2
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Please add your Claude API key in Settings to enable AI features.")
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
    ContentView()
        .modelContainer(for: [Book.self, Passage.self], inMemory: true)
}
