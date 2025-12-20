//
//  BookTests.swift
//  ReadingCompanionTests
//
//  Tests for Book model computed properties.
//

import Testing
import Foundation
@testable import ReadingCompanion

@Suite("Book Model Tests")
struct BookTests {

    // MARK: - passagesUpToCurrentPage Tests

    @Test("Filters passages correctly based on current page")
    func passagesUpToCurrentPage_filtersCorrectly() {
        // Given: A book at page 50 with passages at various pages
        let book = Book(title: "Test Book", currentPage: 50)
        let passage1 = Passage(text: "Early passage", pageNumber: 10, book: book)
        let passage2 = Passage(text: "Middle passage", pageNumber: 50, book: book)
        let passage3 = Passage(text: "Future passage", pageNumber: 100, book: book)
        book.passages = [passage1, passage2, passage3]

        // When: Getting passages up to current page
        let result = book.passagesUpToCurrentPage

        // Then: Only passages at or before page 50 are included
        #expect(result.count == 2)
        #expect(result.contains { $0.text == "Early passage" })
        #expect(result.contains { $0.text == "Middle passage" })
        #expect(!result.contains { $0.text == "Future passage" })
    }

    @Test("Sorts passages in ascending page order")
    func passagesUpToCurrentPage_sortsAscending() {
        // Given: A book with passages added out of order
        let book = Book(title: "Test Book", currentPage: 100)
        let passage1 = Passage(text: "Page 50", pageNumber: 50, book: book)
        let passage2 = Passage(text: "Page 10", pageNumber: 10, book: book)
        let passage3 = Passage(text: "Page 30", pageNumber: 30, book: book)
        book.passages = [passage1, passage2, passage3]

        // When: Getting passages up to current page
        let result = book.passagesUpToCurrentPage

        // Then: Passages are sorted ascending by page number
        #expect(result.count == 3)
        #expect(result[0].pageNumber == 10)
        #expect(result[1].pageNumber == 30)
        #expect(result[2].pageNumber == 50)
    }

    @Test("Handles nil page numbers as page 0")
    func passagesUpToCurrentPage_handlesNilPageNumbers() {
        // Given: A book with passages that have nil page numbers
        let book = Book(title: "Test Book", currentPage: 10)
        let passageWithNil = Passage(text: "No page number", pageNumber: nil, book: book)
        let passageWithPage = Passage(text: "Has page number", pageNumber: 5, book: book)
        book.passages = [passageWithNil, passageWithPage]

        // When: Getting passages up to current page
        let result = book.passagesUpToCurrentPage

        // Then: Nil page numbers are treated as 0 and included
        #expect(result.count == 2)
        #expect(result[0].pageNumber == nil) // nil (treated as 0) comes first
        #expect(result[1].pageNumber == 5)
    }

    @Test("Returns empty array when no passages exist")
    func passagesUpToCurrentPage_emptyWhenNoPassages() {
        // Given: A book with no passages
        let book = Book(title: "Empty Book", currentPage: 50)

        // When: Getting passages up to current page
        let result = book.passagesUpToCurrentPage

        // Then: Result is empty
        #expect(result.isEmpty)
    }

    // MARK: - progressDescription Tests

    @Test("Shows percentage when total pages is set")
    func progressDescription_showsPercentageWithTotalPages() {
        // Given: A book with current page and total pages
        let book = Book(title: "Test Book", currentPage: 50, totalPages: 200)

        // When: Getting progress description
        let result = book.progressDescription

        // Then: Shows page X of Y (Z%)
        #expect(result == "Page 50 of 200 (25%)")
    }

    @Test("Shows only page number when no total pages")
    func progressDescription_showsPageOnlyWithoutTotal() {
        // Given: A book with current page but no total
        let book = Book(title: "Test Book", currentPage: 75, totalPages: nil)

        // When: Getting progress description
        let result = book.progressDescription

        // Then: Shows just the page number
        #expect(result == "Page 75")
    }

    @Test("Shows 'Not started' when current page is 0")
    func progressDescription_showsNotStartedAtZero() {
        // Given: A book at page 0
        let book = Book(title: "New Book", currentPage: 0, totalPages: nil)

        // When: Getting progress description
        let result = book.progressDescription

        // Then: Shows not started
        #expect(result == "Not started")
    }

    @Test("Handles zero total pages gracefully")
    func progressDescription_handlesZeroTotalPages() {
        // Given: A book with total pages set to 0 (edge case)
        let book = Book(title: "Edge Case", currentPage: 10, totalPages: 0)

        // When: Getting progress description
        let result = book.progressDescription

        // Then: Falls back to showing just the page (avoids division by zero)
        #expect(result == "Page 10")
    }
}
