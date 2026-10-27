import Foundation
import Testing
@testable import Selah

struct WidgetSnapshotTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.firstWeekday = 2
        return calendar
    }

    /// October 2026: the 18th is a Sunday, the 19th a Monday.
    private func day(_ day: Int, _ hour: Int = 12) -> Date {
        var parts = DateComponents()
        parts.year = 2026
        parts.month = 10
        parts.day = day
        parts.hour = hour
        return calendar.date(from: parts) ?? Date()
    }

    private let passages = [
        WidgetSnapshotBuilder.Passage(text: "For God so loved the world.", reference: "John 3:16 (KJV)"),
        WidgetSnapshotBuilder.Passage(text: "The Lord is my shepherd.", reference: "Psalm 23:1 (KJV)"),
        WidgetSnapshotBuilder.Passage(text: String(repeating: "word ", count: 80), reference: "Too long")
    ]

    private func build(
        studyDays: [Int] = [16, 17, 18],
        chosen: WidgetSnapshotBuilder.Passage? = nil,
        mood: MascotMood? = nil,
        moodDate: Date? = nil,
        now: Date? = nil
    ) -> WidgetSnapshot {
        WidgetSnapshotBuilder.build(
            input: StreakInput(studyDates: studyDays.map { day($0) }),
            kind: .study,
            mascotMode: .sky,
            chosenVerse: chosen,
            passages: passages,
            mood: mood,
            moodDate: moodDate,
            now: now ?? day(18, 20),
            calendar: calendar
        )
    }

    // MARK: Builder

    @Test func coversAWeekOfDaysFromToday() {
        let snapshot = build()
        #expect(snapshot.streakDays.count == WidgetSnapshotBuilder.daysAhead)
        #expect(snapshot.streakDays.first?.date == calendar.startOfDay(for: day(18)))
        #expect(snapshot.mascotMode == "sky")
        #expect(snapshot.streakKind == "study")
    }

    @Test func todayCountsTheStreakAndLaterDaysAssumeNothingMoreIsLogged() {
        let days = build().streakDays
        #expect(days[0].current == 3)
        #expect(days[0].doneToday)
        // Tomorrow: still alive, not done yet.
        #expect(days[1].current == 3)
        #expect(days[1].doneToday == false)
        // The day after: tomorrow was missed, so the streak is over.
        #expect(days[2].current == 0)
        #expect(days[2].best == 3)
    }

    @Test func weekRowHasSevenCellsWithTodayMarked() {
        let today = build().streakDays[0]
        #expect(today.week.count == 7)
        #expect(today.week.filter(\.isToday).count == 1)
        #expect(today.week.first { $0.isToday }?.state == "done")
    }

    @Test func chosenVerseIsUsedTodayAndPassagesAfter() {
        let chosen = WidgetSnapshotBuilder.Passage(text: "Rejoice in the Lord alway.", reference: "Philippians 4:4 (KJV)")
        let verses = build(chosen: chosen).verses
        #expect(verses.count == WidgetSnapshotBuilder.daysAhead)
        #expect(verses[0].chosen)
        #expect(verses[0].text == chosen.text)
        #expect(verses[1].chosen == false)
    }

    @Test func longPassagesAreSkipped() {
        let verses = build().verses
        #expect(verses.allSatisfy { $0.reference != "Too long" })
    }

    @Test func dailyPassageChangesDayToDayAndStaysPutWithinADay() {
        let short = Array(passages.prefix(2))
        let morning = WidgetSnapshotBuilder.dailyPassage(short, on: day(18, 6), calendar: calendar)
        let evening = WidgetSnapshotBuilder.dailyPassage(short, on: day(18, 22), calendar: calendar)
        let tomorrow = WidgetSnapshotBuilder.dailyPassage(short, on: day(19), calendar: calendar)
        #expect(morning == evening)
        #expect(morning != tomorrow)
    }

    @Test func moodIsKeptOnlyWhenItIsFromToday() {
        #expect(build(mood: .grateful, moodDate: day(18, 8)).moodRaw == "grateful")
        #expect(build(mood: .grateful, moodDate: day(17, 8)).moodRaw == nil)
    }

    @Test func sameDataGivesTheSameSnapshotAtDifferentTimesOfDay() {
        #expect(build(now: day(18, 9)) == build(now: day(18, 21)))
    }

    // MARK: Display

    @Test func displayPicksTheMatchingDay() {
        let snapshot = build()
        let tomorrow = WidgetDisplay.streak(in: snapshot, on: day(19, 7), calendar: calendar)
        #expect(tomorrow?.count == 3)
        #expect(tomorrow?.doneToday == false)
        #expect(tomorrow?.kindTitle == "Study")
        #expect(WidgetDisplay.streak(in: snapshot, on: day(30), calendar: calendar) == nil)
        #expect(WidgetDisplay.streak(in: nil, on: day(18), calendar: calendar) == nil)
    }

    @Test func zeroStreakIsNotLit() {
        let snapshot = build(studyDays: [])
        #expect(WidgetDisplay.streak(in: snapshot, on: day(18), calendar: calendar)?.lit == false)
        #expect(WidgetDisplay.streak(in: build(), on: day(18), calendar: calendar)?.lit == true)
    }

    @Test func verseFallsBackToTheNewestEarlierVerse() {
        let snapshot = build()
        let late = WidgetDisplay.verse(in: snapshot, on: day(30), calendar: calendar)
        #expect(late == snapshot.verses.last)
        #expect(WidgetDisplay.verse(in: snapshot, on: day(10), calendar: calendar) == nil)
    }

    @Test func moodShowsOnlyOnItsDay() {
        let snapshot = build(mood: .loved, moodDate: day(18, 8))
        #expect(WidgetDisplay.mood(in: snapshot, on: day(18, 23), calendar: calendar) == "loved")
        #expect(WidgetDisplay.mood(in: snapshot, on: day(19, 1), calendar: calendar) == nil)
    }

    @Test func refreshDatesAreTheComingMidnights() {
        let dates = WidgetDisplay.refreshDates(in: build(), after: day(18, 20), calendar: calendar)
        #expect(dates.count == WidgetSnapshotBuilder.daysAhead - 1)
        #expect(dates.first == calendar.startOfDay(for: day(19)))
    }

    // MARK: App group and built-in verses

    @Test func appGroupsAreReadFromAProvisioningProfile() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict><key>Entitlements</key><dict>
        <key>com.apple.security.application-groups</key>
        <array><string>group.com.aarondaniel.selah.ABC123</string></array>
        </dict></dict></plist>
        """
        // The plist sits inside binary signature bytes in a real profile.
        var data = Data([0x30, 0x82, 0x0F, 0xFF, 0x00])
        data.append(Data(plist.utf8))
        data.append(Data([0x00, 0xA0, 0x82]))
        #expect(AppGroup.groups(fromProvisionData: data) == ["group.com.aarondaniel.selah.ABC123"])
    }

    @Test func profileWithoutGroupsGivesNone() {
        #expect(AppGroup.groups(fromProvisionData: Data("not a profile".utf8)).isEmpty)
    }

    @Test func builtInVerseChangesDailyAndIsKJV() {
        let today = WidgetFallbackVerses.verse(on: day(18, 6), calendar: calendar)
        #expect(today == WidgetFallbackVerses.verse(on: day(18, 22), calendar: calendar))
        #expect(today.text != WidgetFallbackVerses.verse(on: day(19), calendar: calendar).text)
        #expect(WidgetFallbackVerses.all.allSatisfy { $0.reference.hasSuffix("(KJV)") && !$0.text.isEmpty })
    }

    @Test func snapshotSurvivesJSON() throws {
        let snapshot = build(mood: .joyful, moodDate: day(18, 8))
        let data = try JSONEncoder().encode(snapshot)
        #expect(try JSONDecoder().decode(WidgetSnapshot.self, from: data) == snapshot)
    }
}
