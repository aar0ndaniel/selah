import Foundation
import SwiftData
import Testing
@testable import Selah

struct MoodCheckInLogicTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// October 2026.
    private func day(_ day: Int, _ hour: Int = 12) -> Date {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 10
        parts.day = day
        parts.hour = hour
        return calendar.date(from: parts) ?? Date()
    }

    @Test func dueWhenThereIsNoEntryToday() {
        #expect(MoodCheckInLogic.isDue(entryDates: [], skippedAt: nil, now: day(20), calendar: calendar))
        #expect(MoodCheckInLogic.isDue(entryDates: [day(19), day(18)], skippedAt: nil, now: day(20), calendar: calendar))
    }

    @Test func notDueWhenAnEntryExistsToday() {
        #expect(!MoodCheckInLogic.isDue(entryDates: [day(20, 7)], skippedAt: nil, now: day(20, 21), calendar: calendar))
    }

    @Test func notDueAfterNotNowToday() {
        #expect(!MoodCheckInLogic.isDue(entryDates: [], skippedAt: day(20, 8), now: day(20, 18), calendar: calendar))
    }

    @Test func dueAgainTheNextDay() {
        // "Not now" yesterday, and an entry yesterday: both are over today.
        #expect(MoodCheckInLogic.isDue(entryDates: [day(19)], skippedAt: day(19, 22), now: day(20, 6), calendar: calendar))
    }

    @Test func midnightStartsANewDay() {
        #expect(!MoodCheckInLogic.isDue(entryDates: [day(19, 23)], skippedAt: nil, now: day(19, 23), calendar: calendar))
        #expect(MoodCheckInLogic.isDue(entryDates: [day(19, 23)], skippedAt: nil, now: day(20, 0), calendar: calendar))
    }

    @Test func storedSkipValue() {
        #expect(MoodCheckInLogic.skippedDate(from: 0) == nil)
        #expect(MoodCheckInLogic.skippedDate(from: 1_700_000_000) == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func textForTodayRowAndHeadline() {
        #expect(MoodCheckInLogic.todayRowText(for: nil) == "How are you feeling?")
        #expect(MoodCheckInLogic.todayRowText(for: .joyful) == "Feeling joyful")
        #expect(MoodCheckInLogic.headline(name: "Ama") == "How are you feeling today, Ama?")
        #expect(MoodCheckInLogic.headline(name: "  ") == "How are you feeling today?")
        #expect(MoodCheckInLogic.headline(name: "") == "How are you feeling today?")
    }
}

struct MascotTypesTests {
    @Test func modeRawValuesRoundTrip() throws {
        #expect(MascotMode.allCases.map { $0.rawValue } == ["coral", "sky", "sunshine", "leaf", "peach", "sand"])
        for mode in MascotMode.allCases {
            #expect(MascotMode(rawValue: mode.rawValue) == mode)
            let data = try JSONEncoder().encode(mode)
            #expect(try JSONDecoder().decode(MascotMode.self, from: data) == mode)
        }
    }

    @Test func moodRawValuesRoundTrip() throws {
        #expect(MascotMood.allCases.count == 8)
        for mood in MascotMood.allCases {
            #expect(MascotMood(rawValue: mood.rawValue) == mood)
            let data = try JSONEncoder().encode(mood)
            #expect(try JSONDecoder().decode(MascotMood.self, from: data) == mood)
        }
        #expect(MascotMood(rawValue: "unknown") == nil)
    }

    @Test func moodTitlesAreDistinctAndCapitalised() {
        let titles = MascotMood.allCases.map { $0.title }
        #expect(Set(titles).count == titles.count)
        for (mood, title) in zip(MascotMood.allCases, titles) {
            #expect(title.lowercased() == mood.rawValue)
            #expect(title.first?.isUppercase == true)
        }
    }

    @Test func everyMoodHasADistinctFace() {
        // The drawn face of each mood differs from every other in eyes, brows, mouth or extra.
        var seen = Set<String>()
        for mood in MascotMood.allCases {
            let key = "\(mood.eyes)-\(mood.brows)-\(mood.mouth)-\(mood.extra)"
            #expect(!seen.contains(key))
            seen.insert(key)
        }
    }

    @Test func eyesAndMouthsAreAllDistinctToo() {
        // Stronger: no two moods share the same eyes, and none share the same mouth except the two gentle smiles.
        let eyes = MascotMood.allCases.map { "\($0.eyes)" }
        #expect(Set(eyes).count == eyes.count)
        let extras = MascotMood.allCases.map { "\($0.extra)" }
        #expect(Set(extras).count == extras.count)
    }

    @Test func shiftingWrapsAround() {
        #expect(MascotMood.joyful.shifted(by: 1) == .peaceful)
        #expect(MascotMood.joyful.shifted(by: -1) == .angry)
        #expect(MascotMood.angry.shifted(by: 1) == .joyful)
        #expect(MascotMood.sad.shifted(by: 8) == .sad)
        #expect(MascotMood.sad.shifted(by: -9) == .tired)
    }

    @Test func storedModeFallsBackToCoral() {
        #expect(MascotMode(storedValue: "leaf") == .leaf)
        #expect(MascotMode(storedValue: "mint") == .coral)
        #expect(MascotMode(storedValue: "") == .coral)
        #expect(MascotMode.storageKey == "mascotMode")
        #expect(MascotMode.coral.appIconName == nil)
        #expect(MascotMode.sky.appIconName == "AppIcon-Sky")
    }

    @Test func dropInAssetNames() {
        #expect(MascotImages.assetName(activity: .headset, mood: nil, mode: .sky) == "Mascot-headset-sky")
        #expect(MascotImages.assetName(activity: .neutral, mood: nil, mode: .coral) == "Mascot-neutral-coral")
        #expect(MascotImages.assetName(activity: .neutral, mood: .joyful, mode: .leaf) == "Mascot-mood-joyful-leaf")
        #expect(MascotImages.assetName(activity: .reading, mood: .joyful, mode: .leaf) == nil)
    }
}

@MainActor
struct MoodBackupTests {
    private func makeContext() throws -> ModelContext {
        let schema = Schema(SampleData.allModels)
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return ModelContext(container)
    }

    @Test func moodEntryStoresTheRawValue() {
        let entry = MoodEntry(mood: .anxious)
        #expect(entry.moodRaw == "anxious")
        entry.mood = .loved
        #expect(entry.moodRaw == "loved")
        entry.moodRaw = "from-a-newer-version"
        #expect(entry.mood == .peaceful)
    }

    @Test func backupRoundTripKeepsMoodEntries() throws {
        let source = try makeContext()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Date(timeIntervalSince1970: 1_700_100_000)
        source.insert(MoodEntry(date: second, mood: .grateful, note: "Thankful", createdAt: second))
        source.insert(MoodEntry(date: first, mood: .tired, note: "", createdAt: first))
        try source.save()

        let backup = try BackupService.makeBackup(from: source, now: second)
        #expect(backup.moods?.count == 2)
        #expect(backup.moods?.first?.mood == "tired")

        let data = try BackupService.encode(backup)
        let decoded = try BackupService.decode(data)
        #expect(decoded == backup)

        let target = try makeContext()
        target.insert(MoodEntry(date: second, mood: .sad, note: "Will be replaced"))
        try target.save()
        try BackupService.restore(decoded, into: target)

        let restored = try target.fetch(FetchDescriptor<MoodEntry>(sortBy: [SortDescriptor(\.date)]))
        #expect(restored.count == 2)
        #expect(restored.map { $0.mood } == [.tired, .grateful])
        #expect(restored.map { $0.note } == ["", "Thankful"])
        #expect(restored.map { $0.date } == [first, second])
    }

    @Test func olderBackupWithoutMoodsStillRestores() throws {
        let source = try makeContext()
        source.insert(MoodEntry(mood: .joyful))
        try source.save()
        var backup = try BackupService.makeBackup(from: source)
        backup.moods = nil

        let data = try BackupService.encode(backup)
        let decoded = try BackupService.decode(data)
        #expect(decoded.moods == nil)

        let target = try makeContext()
        try BackupService.restore(decoded, into: target)
        #expect(try target.fetchCount(FetchDescriptor<MoodEntry>()) == 0)
    }
}
