import XCTest
@testable import SpeakAwayCore

final class UsageStatsTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Panama")!
        return c
    }

    private func day(_ y: Int, _ m: Int, _ d: Int) -> DayKey {
        DayKey(calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 15))!, calendar: calendar)
    }

    func testWordCount() {
        XCTAssertEqual(UsageStats.wordCount("Hola Carla, te mando la cotización."), 6)
        XCTAssertEqual(UsageStats.wordCount("  uno\n\ndos   tres "), 3)
        XCTAssertEqual(UsageStats.wordCount(""), 0)
    }

    func testDaysAcrossAMonthAreConsecutive() {
        XCTAssertEqual(day(2026, 10, 31).adding(1), day(2026, 11, 1))
        XCTAssertEqual(day(2026, 11, 1).ordinal - day(2026, 10, 31).ordinal, 1)
    }

    func testRecordingReturnsANewValue() {
        let empty = UsageStats()
        let one = empty.recording(words: 12, seconds: 6, on: day(2026, 11, 2))
        XCTAssertEqual(empty.totalWords, 0)
        XCTAssertEqual(one.totalWords, 12)
        XCTAssertEqual(one.totalSessions, 1)
        let two = one.recording(words: 8, seconds: 4, on: day(2026, 11, 2))
        XCTAssertEqual(two.totalWords, 20)
        XCTAssertEqual(two.days[day(2026, 11, 2).ordinal]?.sessions, 2)
    }

    func testStreakCountsConsecutiveDaysEndingTodayOrYesterday() {
        let stats = UsageStats()
            .recording(words: 5, seconds: 3, on: day(2026, 10, 30))
            .recording(words: 5, seconds: 3, on: day(2026, 10, 31))
            .recording(words: 5, seconds: 3, on: day(2026, 11, 1))
        XCTAssertEqual(stats.currentStreak(today: day(2026, 11, 1)), 3)
        XCTAssertEqual(stats.currentStreak(today: day(2026, 11, 2)), 3, "still alive until the day ends")
        XCTAssertEqual(stats.currentStreak(today: day(2026, 11, 3)), 0, "a full day without dictating breaks it")
    }

    func testBestStreakSurvivesAGap() {
        let stats = UsageStats()
            .recording(words: 1, seconds: 1, on: day(2026, 10, 1))
            .recording(words: 1, seconds: 1, on: day(2026, 10, 2))
            .recording(words: 1, seconds: 1, on: day(2026, 10, 3))
            .recording(words: 1, seconds: 1, on: day(2026, 10, 4))
            .recording(words: 1, seconds: 1, on: day(2026, 10, 10))
        XCTAssertEqual(stats.bestStreak, 4)
        XCTAssertEqual(stats.currentStreak(today: day(2026, 10, 10)), 1)
    }

    func testEmptyRecordingsDoNotCount() {
        let stats = UsageStats().recording(words: 0, seconds: 2, on: day(2026, 11, 2))
        XCTAssertEqual(stats, UsageStats())
    }

    func testSpeedAndTimeSaved() {
        let stats = UsageStats().recording(words: 400, seconds: 120, on: day(2026, 11, 2))
        XCTAssertEqual(stats.wordsPerMinute, 200)
        // Typing 400 words at 40 wpm takes 10 minutes; speaking took 2.
        XCTAssertEqual(stats.minutesSaved(typingWPM: 40), 8)
        XCTAssertEqual(UsageStats().wordsPerMinute, 0)
        XCTAssertEqual(UsageStats().minutesSaved(typingWPM: 40), 0)
    }

    func testActivityIsOldestFirstWithZerosForQuietDays() {
        let stats = UsageStats()
            .recording(words: 7, seconds: 3, on: day(2026, 10, 31))
            .recording(words: 9, seconds: 3, on: day(2026, 11, 2))
        XCTAssertEqual(stats.activity(endingOn: day(2026, 11, 2), days: 4), [0, 7, 0, 9])
    }

    func testRoundTripsThroughJSON() throws {
        let stats = UsageStats().recording(words: 3, seconds: 2, on: day(2026, 11, 2))
        let back = try JSONDecoder().decode(UsageStats.self, from: JSONEncoder().encode(stats))
        XCTAssertEqual(back, stats)
    }
}

final class MilestoneTests: XCTestCase {
    func testNextMilestoneAndProgress() {
        XCTAssertEqual(Milestone.next(after: 0).target, 1_000)
        XCTAssertEqual(Milestone.next(after: 0).progress, 0, accuracy: 0.0001)
        let m = Milestone.next(after: 3_000)
        XCTAssertEqual(m.target, 5_000)
        XCTAssertEqual(m.previous, 1_000)
        XCTAssertEqual(m.progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(Milestone.next(after: 5_000).target, 10_000, "reaching a milestone moves to the next one")
    }

    func testPastTheLastMilestoneKeepsDoubling() {
        let m = Milestone.next(after: 1_200_000)
        XCTAssertEqual(m.target, 2_000_000)
        XCTAssertGreaterThan(m.progress, 0)
        XCTAssertLessThan(m.progress, 1)
    }
}
