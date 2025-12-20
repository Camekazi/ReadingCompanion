//
//  SettingsView.swift
//  ReadingCompanion
//
//  Settings view for managing API key and app preferences.
//

import SwiftUI

struct SettingsView: View {
    @State private var apiKey = ""
    @State private var hasExistingKey = false
    @State private var showingAPIKey = false
    @State private var saveSuccess = false

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

                Section("Data", content: {
                    NavigationLink(destination: Text("Coming soon")) {
                        Label("Export Library", systemImage: "square.and.arrow.up")
                    }
                    .disabled(true)
                })
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
