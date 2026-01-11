//
//  SettingsView.swift
//  ReadingCompanion
//
//  Settings view for managing API key and app preferences.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var books: [Book]

    @State private var apiKey = ""
    @State private var hasExistingKey = false
    @State private var showingAPIKey = false
    @State private var saveSuccess = false

    // Import/Export state
    @State private var showingImportPicker = false
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var importResult: ImportResult?
    @State private var exportResult: ExportResult?
    @State private var syncError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if hasExistingKey {
                        HStack {
                            if showingAPIKey {
                                Text(apiKey)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                Text("••••••••••••••••")
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button(showingAPIKey ? "Hide" : "Show") {
                                showingAPIKey.toggle()
                            }
                            .buttonStyle(.bordered)
                        }

                        Button("Remove API Key", role: .destructive) {
                            removeAPIKey()
                        }
                    } else {
                        SecureField("Enter your API key", text: $apiKey)
                            .textContentType(.password)
                            .autocorrectionDisabled()

                        Button("Save API Key") {
                            saveAPIKey()
                        }
                        .disabled(apiKey.isEmpty)
                    }
                } header: {
                    Text("Claude API Key")
                } footer: {
                    Text("Your API key is stored securely in the iOS Keychain and never leaves your device except to authenticate with Claude.")
                }

                Section("About", content: {
                    LabeledContent("Version", value: "1.0.0")
                    LabeledContent("Build", value: "1")

                    Link(destination: URL(string: "https://docs.anthropic.com")!) {
                        Label("Claude API Documentation", systemImage: "book")
                    }

                    Link(destination: URL(string: "https://console.anthropic.com")!) {
                        Label("Get API Key", systemImage: "key")
                    }
                })

                Section {
                    // Import from CSV
                    Button {
                        showingImportPicker = true
                    } label: {
                        HStack {
                            Label("Import from CSV", systemImage: "square.and.arrow.down")
                            Spacer()
                            if isImporting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isImporting)

                    // Export to iCloud
                    Button {
                        Task { await exportToICloud() }
                    } label: {
                        HStack {
                            Label("Export to iCloud", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            if isExporting {
                                ProgressView()
                            } else {
                                Text("\(books.count) books")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(isExporting || books.isEmpty)

                    // iCloud status
                    if ImportExportService.shared.isICloudAvailable {
                        Label("iCloud Available", systemImage: "checkmark.icloud")
                            .foregroundStyle(.green)
                    } else {
                        Label("iCloud Not Available", systemImage: "xmark.icloud")
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Sync with Obsidian")
                } footer: {
                    Text("Import books from your Collective Bookshelf CSV. Export creates markdown files in iCloud Documents for Obsidian.")
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                loadExistingKey()
            }
            .alert("API Key Saved", isPresented: $saveSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your Claude API key has been saved securely.")
            }
            .sheet(isPresented: $showingImportPicker) {
                DocumentPickerView(
                    onPick: { url in
                        Task { await importFromCSV(url: url) }
                    },
                    onCancel: {}
                )
            }
            .alert("Import Complete", isPresented: .constant(importResult != nil)) {
                Button("OK") { importResult = nil }
            } message: {
                if let result = importResult {
                    Text(result.summary)
                }
            }
            .alert("Export Complete", isPresented: .constant(exportResult != nil)) {
                Button("OK") { exportResult = nil }
            } message: {
                if let result = exportResult {
                    Text(result.summary)
                }
            }
            .alert("Sync Error", isPresented: .constant(syncError != nil)) {
                Button("OK") { syncError = nil }
            } message: {
                if let error = syncError {
                    Text(error)
                }
            }
        }
    }

    // MARK: - Import/Export

    private func importFromCSV(url: URL) async {
        isImporting = true
        defer { isImporting = false }

        do {
            let result = try await ImportExportService.shared.importFromCSV(url: url, modelContext: modelContext)
            importResult = result
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func exportToICloud() async {
        isExporting = true
        defer { isExporting = false }

        do {
            let result = try ImportExportService.shared.exportAllBooksToICloud(books)
            exportResult = result
        } catch {
            syncError = error.localizedDescription
        }
    }

    private func loadExistingKey() {
        if let existingKey = KeychainService.shared.getAPIKey() {
            apiKey = existingKey
            hasExistingKey = true
        }
    }

    private func saveAPIKey() {
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if KeychainService.shared.saveAPIKey(trimmedKey) {
            hasExistingKey = true
            saveSuccess = true
        }
    }

    private func removeAPIKey() {
        KeychainService.shared.deleteAPIKey()
        apiKey = ""
        hasExistingKey = false
        showingAPIKey = false
    }
}

#Preview {
    SettingsView()
}
