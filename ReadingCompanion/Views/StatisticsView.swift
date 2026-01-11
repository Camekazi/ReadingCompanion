//
//  StatisticsView.swift
//  ReadingCompanion
//
//  View for displaying reading statistics, streaks, and vocabulary progress.
//

import SwiftUI
import SwiftData

struct StatisticsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var sessions: [ReadingSession]
    @Query private var vocabularyWords: [VocabularyWord]
    @Query private var books: [Book]

    private var statistics: ReadingStatistics {
        ReadingStatisticsCalculator.calculate(from: sessions)
    }

    private var vocabularyStats: VocabularyStats {
        let calendar = Calendar.current
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let wordsThisWeek = vocabularyWords.filter { $0.dateAdded >= weekAgo }.count
        let uniqueBookIds = Set(vocabularyWords.compactMap { $0.book?.id })

        return VocabularyStats(
            totalWords: vocabularyWords.count,
            masteredWords: vocabularyWords.filter { $0.isMastered }.count,
            wordsThisWeek: wordsThisWeek,
            uniqueBooks: uniqueBookIds.count
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Streak Hero Card
                    streakCard

                    // Reading Stats Grid
                    readingStatsGrid

                    // Vocabulary Stats
                    vocabularyCard

                    // Weekly Activity
                    weeklyActivityCard
                }
                .padding()
            }
            .navigationTitle("Statistics")
            .background(Color(.systemGroupedBackground))
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: statistics.readToday ? "flame.fill" : "flame")
                    .font(.system(size: 44))
                    .foregroundStyle(statistics.currentStreak > 0 ? .orange : .gray)

                VStack(alignment: .leading, spacing: 4) {
                    Text(statistics.streakDisplay)
                        .font(.title)
                        .fontWeight(.bold)

                    Text(statistics.readToday ? "Keep it going!" : "Read today to continue")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if statistics.longestStreak > statistics.currentStreak {
                HStack {
                    Image(systemName: "trophy.fill")
                        .foregroundStyle(.yellow)
                    Text("Longest streak: \(statistics.longestStreak) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Reading Stats Grid

    private var readingStatsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatCard(
                title: "Pages Read",
                value: "\(statistics.totalPagesRead)",
                icon: "book.pages",
                color: .blue
            )

            StatCard(
                title: "Time Reading",
                value: formatMinutes(statistics.totalMinutesRead),
                icon: "clock.fill",
                color: .green
            )

            StatCard(
                title: "Books",
                value: "\(books.count)",
                icon: "books.vertical.fill",
                color: .purple
            )

            StatCard(
                title: "This Week",
                value: "\(statistics.pagesThisWeek) pages",
                icon: "calendar",
                color: .orange
            )
        }
    }

    // MARK: - Vocabulary Card

    private var vocabularyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "text.book.closed.fill")
                    .foregroundStyle(.indigo)
                Text("Vocabulary")
                    .font(.headline)
                Spacer()
                NavigationLink {
                    VocabularyListView()
                } label: {
                    Text("View All")
                        .font(.subheadline)
                }
            }

            Divider()

            HStack(spacing: 24) {
                VStack(alignment: .leading) {
                    Text("\(vocabularyStats.totalWords)")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Words")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text("\(vocabularyStats.masteredWords)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text("Mastered")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading) {
                    Text(vocabularyStats.masteryDisplay)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    Text("Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            if vocabularyStats.wordsThisWeek > 0 {
                Text("+\(vocabularyStats.wordsThisWeek) words this week")
                    .font(.caption)
                    .foregroundStyle(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Weekly Activity

    private var weeklyActivityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(.teal)
                Text("This Week")
                    .font(.headline)
            }

            Divider()

            HStack(spacing: 8) {
                ForEach(weeklyActivity(), id: \.day) { activity in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(activity.pages > 0 ? Color.teal : Color(.systemGray5))
                            .frame(height: max(4, CGFloat(activity.pages) * 2))
                            .frame(maxHeight: 60)

                        Text(activity.dayLabel)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            HStack {
                Text("\(statistics.sessionsThisWeek) sessions")
                Spacer()
                Text("\(statistics.pagesThisWeek) pages")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
    }

    // MARK: - Helpers

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }

    private func weeklyActivity() -> [DayActivity] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let pages = sessions
                .filter { calendar.isDate($0.date, inSameDayAs: date) }
                .reduce(0) { $0 + $1.pagesRead }

            return DayActivity(day: date, dayLabel: String(dayName.prefix(1)), pages: pages)
        }
    }
}

// MARK: - Supporting Types

private struct DayActivity {
    let day: Date
    let dayLabel: String
    let pages: Int
}

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .modelContainer(for: [Book.self, Passage.self, ReadingSession.self, VocabularyWord.self], inMemory: true)
}
