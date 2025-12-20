//
//  KeychainServiceTests.swift
//  ReadingCompanionTests
//
//  Tests for SecureStorage protocol behavior using MockSecureStorage.
//  These tests verify the contract that KeychainService must fulfill.
//

import Testing
import Foundation
@testable import ReadingCompanion

@Suite("SecureStorage Tests")
struct KeychainServiceTests {

    // MARK: - Setup

    /// Create a fresh mock for each test
    private func makeMock() -> MockSecureStorage {
        MockSecureStorage()
    }

    // MARK: - saveAPIKey Tests

    @Test("Save stores the API key")
    func saveAPIKey_storesKey() {
        // Given: An empty storage
        let storage = makeMock()
        let testKey = "sk-ant-test-key-12345"

        // When: Saving an API key
        let success = storage.saveAPIKey(testKey)

        // Then: The key is stored successfully
        #expect(success == true)
        #expect(storage.storedKey == testKey)
        #expect(storage.saveCallCount == 1)
    }

    @Test("Save overwrites existing key")
    func saveAPIKey_overwritesExistingKey() {
        // Given: Storage with an existing key
        let storage = makeMock()
        _ = storage.saveAPIKey("old-key")

        // When: Saving a new key
        let success = storage.saveAPIKey("new-key")

        // Then: The new key replaces the old one
        #expect(success == true)
        #expect(storage.storedKey == "new-key")
    }

    @Test("Save can fail")
    func saveAPIKey_canFail() {
        // Given: Storage configured to fail
        let storage = makeMock()
        storage.shouldFailSave = true

        // When: Attempting to save
        let success = storage.saveAPIKey("any-key")

        // Then: Save fails and key is not stored
        #expect(success == false)
        #expect(storage.storedKey == nil)
    }

    // MARK: - getAPIKey Tests

    @Test("Get retrieves stored key")
    func getAPIKey_retrievesStoredKey() {
        // Given: Storage with a key
        let storage = makeMock()
        let testKey = "sk-ant-api-key-secret"
        _ = storage.saveAPIKey(testKey)

        // When: Getting the key
        let result = storage.getAPIKey()

        // Then: The correct key is returned
        #expect(result == testKey)
        #expect(storage.getCallCount == 1)
    }

    @Test("Get returns nil when no key stored")
    func getAPIKey_returnsNilWhenEmpty() {
        // Given: Empty storage
        let storage = makeMock()

        // When: Getting the key
        let result = storage.getAPIKey()

        // Then: Nil is returned
        #expect(result == nil)
    }

    // MARK: - deleteAPIKey Tests

    @Test("Delete removes stored key")
    func deleteAPIKey_removesKey() {
        // Given: Storage with a key
        let storage = makeMock()
        _ = storage.saveAPIKey("key-to-delete")

        // When: Deleting the key
        let success = storage.deleteAPIKey()

        // Then: Key is removed
        #expect(success == true)
        #expect(storage.storedKey == nil)
        #expect(storage.deleteCallCount == 1)
    }

    @Test("Delete succeeds even when no key exists")
    func deleteAPIKey_succeedsWhenEmpty() {
        // Given: Empty storage
        let storage = makeMock()

        // When: Deleting (nothing to delete)
        let success = storage.deleteAPIKey()

        // Then: Operation still succeeds
        #expect(success == true)
    }

    @Test("Delete can fail")
    func deleteAPIKey_canFail() {
        // Given: Storage configured to fail delete
        let storage = makeMock()
        _ = storage.saveAPIKey("persistent-key")
        storage.shouldFailDelete = true

        // When: Attempting to delete
        let success = storage.deleteAPIKey()

        // Then: Delete fails, key remains
        #expect(success == false)
        #expect(storage.storedKey == "persistent-key")
    }

    // MARK: - hasAPIKey Tests

    @Test("hasAPIKey returns true when key exists")
    func hasAPIKey_returnsTrueWhenKeyExists() {
        // Given: Storage with a key
        let storage = makeMock()
        _ = storage.saveAPIKey("test-key")

        // When/Then: hasAPIKey is true
        #expect(storage.hasAPIKey == true)
    }

    @Test("hasAPIKey returns false when no key")
    func hasAPIKey_returnsFalseWhenEmpty() {
        // Given: Empty storage
        let storage = makeMock()

        // When/Then: hasAPIKey is false
        #expect(storage.hasAPIKey == false)
    }

    @Test("hasAPIKey updates after delete")
    func hasAPIKey_updatesAfterDelete() {
        // Given: Storage with a key
        let storage = makeMock()
        _ = storage.saveAPIKey("temp-key")
        #expect(storage.hasAPIKey == true)

        // When: Deleting the key
        _ = storage.deleteAPIKey()

        // Then: hasAPIKey is now false
        #expect(storage.hasAPIKey == false)
    }

    // MARK: - Lifecycle Tests

    @Test("Full lifecycle: save, get, delete")
    func fullLifecycle() {
        // Given: Empty storage
        let storage = makeMock()
        let testKey = "sk-ant-lifecycle-test"

        // When/Then: Full CRUD cycle
        #expect(storage.hasAPIKey == false)

        // Save
        let saveResult = storage.saveAPIKey(testKey)
        #expect(saveResult == true)
        #expect(storage.hasAPIKey == true)

        // Get
        let retrieved = storage.getAPIKey()
        #expect(retrieved == testKey)

        // Delete
        let deleteResult = storage.deleteAPIKey()
        #expect(deleteResult == true)
        #expect(storage.hasAPIKey == false)
        #expect(storage.getAPIKey() == nil)
    }
}
