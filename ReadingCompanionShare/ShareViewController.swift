//
//  ShareViewController.swift
//  ReadingCompanionShare
//
//  Share Extension for adding passages from other apps.
//  Saves to App Group for main app to import.
//

import UIKit
import SwiftUI
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Extract shared text
        guard let extensionItem = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachments = extensionItem.attachments else {
            cancel()
            return
        }

        // Find text attachment
        for attachment in attachments {
            if attachment.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] text, error in
                    DispatchQueue.main.async {
                        if let text = text as? String {
                            self?.showPassageForm(with: text)
                        } else {
                            self?.cancel()
                        }
                    }
                }
                return
            }

            // Also check for URL (might contain text)
            if attachment.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                attachment.loadItem(forTypeIdentifier: UTType.url.identifier) { [weak self] url, error in
                    DispatchQueue.main.async {
                        if let url = url as? URL {
                            self?.showPassageForm(with: url.absoluteString)
                        } else {
                            self?.cancel()
                        }
                    }
                }
                return
            }
        }

        cancel()
    }

    private func showPassageForm(with text: String) {
        let formView = ShareFormView(
            passageText: text,
            onSave: { [weak self] bookTitle, pageNumber, passageText in
                self?.savePassage(bookTitle: bookTitle, pageNumber: pageNumber, text: passageText)
            },
            onCancel: { [weak self] in
                self?.cancel()
            }
        )

        let hostingController = UIHostingController(rootView: formView)
        hostingController.view.frame = view.bounds
        hostingController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)
    }

    private func savePassage(bookTitle: String, pageNumber: Int?, text: String) {
        // Save to App Group shared container
        let passage = PendingPassage(
            bookTitle: bookTitle,
            pageNumber: pageNumber,
            text: text,
            dateAdded: Date()
        )

        var pending = loadPendingPassages()
        pending.append(passage)
        savePendingPassages(pending)

        // Complete with success
        extensionContext?.completeRequest(returningItems: nil)
    }

    private func cancel() {
        extensionContext?.cancelRequest(withError: NSError(domain: "ReadingCompanionShare", code: 0))
    }

    // MARK: - App Group Storage

    private var appGroupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.readingcompanion.shared")
    }

    private var pendingPassagesURL: URL? {
        appGroupURL?.appendingPathComponent("pendingPassages.json")
    }

    private func loadPendingPassages() -> [PendingPassage] {
        guard let url = pendingPassagesURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([PendingPassage].self, from: data)
        } catch {
            return []
        }
    }

    private func savePendingPassages(_ passages: [PendingPassage]) {
        guard let url = pendingPassagesURL else { return }

        do {
            let data = try JSONEncoder().encode(passages)
            try data.write(to: url)
        } catch {
            print("Failed to save pending passages: \(error)")
        }
    }
}

// MARK: - Data Models

struct PendingPassage: Codable {
    let bookTitle: String
    let pageNumber: Int?
    let text: String
    let dateAdded: Date
}

// MARK: - SwiftUI Form

struct ShareFormView: View {
    let passageText: String
    let onSave: (String, Int?, String) -> Void
    let onCancel: () -> Void

    @State private var bookTitle: String = ""
    @State private var pageNumberString: String = ""
    @State private var editedText: String

    init(passageText: String,
         onSave: @escaping (String, Int?, String) -> Void,
         onCancel: @escaping () -> Void) {
        self.passageText = passageText
        self.onSave = onSave
        self.onCancel = onCancel
        _editedText = State(initialValue: passageText)
    }

    private var pageNumber: Int? {
        Int(pageNumberString)
    }

    private var canSave: Bool {
        !bookTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editedText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Book")) {
                    TextField("Book Title", text: $bookTitle)
                        .autocorrectionDisabled()
                    TextField("Page Number (optional)", text: $pageNumberString)
                        .keyboardType(.numberPad)
                }

                Section(header: Text("Passage")) {
                    TextEditor(text: $editedText)
                        .frame(minHeight: 150)
                }

                Section {
                    Text("This passage will be imported into Reading Companion the next time you open the app.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Save Passage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(bookTitle.trimmingCharacters(in: .whitespaces),
                               pageNumber,
                               editedText.trimmingCharacters(in: .whitespaces))
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
