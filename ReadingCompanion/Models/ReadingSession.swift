//
//  ReadingSession.swift
//  ReadingCompanion
//
//  SwiftData model for tracking reading sessions and calculating streaks.
//

import Foundation
import SwiftData

@Model
final class ReadingSession {
    var id: UUID
    var date: Date              // Start of session
    var endDate: Date?          // End of session (nil if ongoing)
    var pagesRead: Int          // Number of pages read in this session
    var startPage: Int          // Page number at start
    var endPage: Int            // Page number at end

    var book: Book?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        endDate: Date? = nil,
        pagesRead: Int = 0,
        startPage: Int = 0,
        endPage: Int = 0,
        book: Book? = nil
    ) {
        self.id = id
        self.date = date
        self.endDate = endDate
        self.pagesRead = pagesRead
        self.startPage = startPage
        self.endPage = endPage
        self.book = book
    }

    /// Duration of the session in minutes
    var durationMinutes: Int {
        guard let end = endDate else { return 0 }
        return Int(end.timeIntervalSince(date) / 60)
    }

    /// Formatted duration string (e.g., "45 min" or "1h 23min")
    var formattedDuration: String {
        let minutes = durationMinutes
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if remainingMinutes == 0 {
            return "\(hours)h"
        }
        return "\(hours)h \(remainingMinutes)min"
    }

    /// Calendar day of this session (for grouping)
    var calendarDay: Date {
        Calendar.current.startOfDay(for: date)
    }
}

// MARK: - Reading Statistics Helper

/// Aggregated reading statistics across all sessions
struct ReadingStatistics {
    let totalPagesRead: Int
    let totalMinutesRead: Int
    let currentStreak: Int          // Days in a row
    let longestStreak: Int
    let sessionsThisWeek: Int
    let pagesThisWeek: Int
    let averagePagesPerSession: Double
    let lastReadDate: Date?

    /// Check if user read today
    var readToday: Bool {
        guard let lastRead = lastReadDate else { return false }
        return Calendar.current.isDateInToday(lastRead)
    }

    /// Formatted streak display
    var streakDisplay: String {
        if currentStreak == 0 {
            return "No streak"
        } else if currentStreak == 1 {
            return "1 day"
        } else {
            return "\(currentStreak) days"
        }
    }

    static let empty = ReadingStatistics(
        totalPagesRead: 0,
        totalMinutesRead: 0,
        currentStreak: 0,
        longestStreak: 0,
        sessionsThisWeek: 0,
        pagesThisWeek: 0,
        averagePagesPerSession: 0,
        lastReadDate: nil
    )
}

// MARK: - Statistics Calculator

@MainActor
class ReadingStatisticsCalculator {

    /// Calculate statistics from a list of reading sessions
    static func calculate(from sessions: [ReadingSession]) -> ReadingStatistics {
        guard !sessions.isEmpty else { return .empty }

        let sortedSessions = sessions.sorted { $0.date > $1.date }

        // Total pages and time
        let totalPages = sessions.reduce(0) { $0 + $1.pagesRead }
        let totalMinutes = sessions.reduce(0) { $0 + $1.durationMinutes }

        // This week's stats
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let thisWeekSessions = sessions.filter { $0.date >= weekAgo }
        let pagesThisWeek = thisWeekSessions.reduce(0) { $0 + $1.pagesRead }

        // Calculate streaks
        let (currentStreak, longestStreak) = calculateStreaks(from: sortedSessions)

        // Average pages per session
        let avgPages = sessions.isEmpty ? 0 : Double(totalPages) / Double(sessions.count)

        return ReadingStatistics(
            totalPagesRead: totalPages,
            totalMinutesRead: totalMinutes,
            currentStreak: currentStreak,
            longestStreak: longestStreak,
            sessionsThisWeek: thisWeekSessions.count,
            pagesThisWeek: pagesThisWeek,
            averagePagesPerSession: avgPages,
            lastReadDate: sortedSessions.first?.date
        )
    }

    /// Calculate current and longest streak from sessions
    private static func calculateStreaks(from sortedSessions: [ReadingSession]) -> (current: Int, longest: Int) {
        guard !sortedSessions.isEmpty else { return (0, 0) }

        let calendar = Calendar.current

        // Get unique reading days (sorted descending)
        var readingDays: Set<Date> = []
        for session in sortedSessions {
            readingDays.insert(calendar.startOfDay(for: session.date))
        }
        let sortedDays = readingDays.sorted(by: >)

        guard !sortedDays.isEmpty else { return (0, 0) }

        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!

        // Current streak: must include today or yesterday
        var currentStreak = 0
        let checkDate = sortedDays[0]

        // Only count current streak if most recent read was today or yesterday
        if checkDate == today || checkDate == yesterday {
            currentStreak = 1
            var lastDay = checkDate

            for day in sortedDays.dropFirst() {
                let expectedPrevious = calendar.date(byAdding: .day, value: -1, to: lastDay)!
                if day == expectedPrevious {
                    currentStreak += 1
                    lastDay = day
                } else {
                    break
                }
            }
        }

        // Longest streak (scan all days)
        var longestStreak = 1
        var tempStreak = 1

        for i in 1..<sortedDays.count {
            let expectedPrevious = calendar.date(byAdding: .day, value: -1, to: sortedDays[i-1])!
            if sortedDays[i] == expectedPrevious {
                tempStreak += 1
                longestStreak = max(longestStreak, tempStreak)
            } else {
                tempStreak = 1
            }
        }

        return (currentStreak, max(longestStreak, currentStreak))
    }
}
