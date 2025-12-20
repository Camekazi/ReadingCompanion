//
//  MockSecureStorage.swift
//  ReadingCompanionTests
//
//  Mock implementation of SecureStorage for testing.
//

import Foundation
@testable import ReadingCompanion

/// Mock implementation of SecureStorage for unit testing.
/// Stores keys in memory instead of the actual Keychain.
class MockSecureStorage: SecureStorage {

    // MARK: - Internal State

    /// The stored API key (nil if no key stored)
    private(set) var storedKey: String?

    /// Tracks whether save was called
    private(set) var saveCallCount = 0

    /// Tracks whether get was called
    private(set) var getCallCount = 0

    /// Tracks whether delete was called
    private(set) var deleteCallCount = 0

    /// If true, save operations will fail
    var shouldFailSave = false

    /// If true, delete operations will fail
    var shouldFailDelete = false

    // MARK: - SecureStorage Protocol

    func saveAPIKey(_ apiKey: String) -> Bool {
        saveCallCount += 1

        if shouldFailSave {
            return false
        }

        storedKey = apiKey
        return true
    }

    func getAPIKey() -> String? {
        getCallCount += 1
        return storedKey
    }

    func deleteAPIKey() -> Bool {
        deleteCallCount += 1

        if shouldFailDelete {
            return false
        }

        storedKey = nil
        return true
    }

    var hasAPIKey: Bool {
        storedKey != nil
    }

    // MARK: - Test Helpers

    /// Reset the mock to initial state
    func reset() {
        storedKey = nil
        saveCallCount = 0
        getCallCount = 0
        deleteCallCount = 0
        shouldFailSave = false
        shouldFailDelete = false
    }
}
