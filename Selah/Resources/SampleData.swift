import Foundation
import SwiftData

/// In-memory sample store for previews and tests.
@MainActor
enum SampleData {
    static let allModels: [any PersistentModel.Type] = [
        UserProfile.self,
        MeetingDay.self,
        ReadingPlan.self,
        ReadingReminder.self,
        StudyEntry.self,
        Service.self,
        Song.self,
        PersonalNote.self,
        VerseRef.self,
        NoteComment.self
    ]

    static let container: ModelContainer = makeContainer()

    private static func makeContainer() -> ModelContainer {
        do {
            let schema = Schema(allModels)
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            populate(container.mainContext)
            return container
        } catch {
            fatalError("Could not create the sample container: \(error)")
        }
    }

    // MARK: - Helpers

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 9, _ minute: Int = 0) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = hour
        parts.minute = minute
        return Calendar.current.date(from: parts) ?? Date()
    }

    private static func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
    }

    private static func verse(
        _ book: String,
        _ chapter: Int,
        _ start: Int,
        _ end: Int,
        _ text: String,
        part: VersePart = .none
    ) -> VerseRef {
        VerseRef(
            book: book,
            chapter: chapter,
            verseStart: start,
            verseEnd: end,
            translation: .kjv,
            textSnapshot: text,
            part: part
        )
    }

    /// Plain text with one highlighted phrase and its matching comment.
    private static func highlighted(_ text: String, phrase: String, id: String) -> AttributedString {
        var result = AttributedString(text)
        if let range = result.range(of: phrase) {
            result[range][HighlightIDAttribute.self] = id
        }
        return result
    }

    // MARK: - Populate

    private static func populate(_ context: ModelContext) {
        // Profile
        context.insert(UserProfile(
            name: "Daniel",
            congregation: "Grace Chapel",
            translation: .kjv,
            textSize: 17,
            appearance: .system,
            onboarded: true
        ))

        // Meeting days (Calendar weekday: 1 Sunday ... 7 Saturday)
        context.insert(MeetingDay(weekday: 3, hour: 18, minute: 30, name: "Bible study", reminderMinutesBefore: 60))
        context.insert(MeetingDay(weekday: 6, hour: 18, minute: 30, name: "Prayer meeting", reminderMinutesBefore: 60))
        context.insert(MeetingDay(weekday: 1, hour: 9, minute: 0, name: "Sunday worship", reminderMinutesBefore: 90))

        // Philippians: reading, chapters 1 and 2 read
        let philippians = ReadingPlan(
            bookName: "Philippians",
            totalChapters: 4,
            status: .reading,
            plannedDays: 4,
            startDate: daysAgo(2),
            chaptersRead: [1, 2]
        )
        context.insert(philippians)
        let reminder = ReadingReminder(hour: 7, minute: 0)
        context.insert(reminder)
        reminder.plan = philippians

        let phil1Note = "Paul is sure God finishes what he starts. My progress rests on his faithfulness, not mine."
        let entry1 = StudyEntry(
            date: daysAgo(2),
            chapter: 1,
            note: highlighted(phil1Note, phrase: "God finishes what he starts", id: "sample-highlight-1")
        )
        context.insert(entry1)
        entry1.plan = philippians
        let best1 = verse(
            "Philippians", 1, 6, 6,
            "Being confident of this very thing, that he which hath begun a good work in you will perform it until the day of Jesus Christ:"
        )
        context.insert(best1)
        entry1.bestVerse = best1
        let comment1 = NoteComment(
            highlightID: "sample-highlight-1",
            quotedText: "God finishes what he starts",
            comment: "Good to remember on days I feel I am not growing.",
            field: .body
        )
        context.insert(comment1)
        comment1.studyEntry = entry1

        let entry2 = StudyEntry(
            date: daysAgo(1),
            chapter: 2,
            note: AttributedString("Christ gave up his rights to serve. Humility is choosing the lower seat on purpose.")
        )
        context.insert(entry2)
        entry2.plan = philippians
        let best2 = verse("Philippians", 2, 5, 5, "Let this mind be in you, which was also in Christ Jesus:")
        context.insert(best2)
        entry2.bestVerse = best2

        let entry3 = StudyEntry(
            date: daysAgo(0),
            chapter: 2,
            note: AttributedString("Reread the second half. Timothy and Epaphroditus show what servant hearts look like.")
        )
        context.insert(entry3)
        entry3.plan = philippians
        let best3 = verse("Philippians", 2, 14, 14, "Do all things without murmurings and disputings:")
        context.insert(best3)
        entry3.bestVerse = best3

        // James: up next
        context.insert(ReadingPlan(
            bookName: "James",
            totalChapters: 5,
            status: .upNext,
            plannedDays: 5
        ))

        // Ruth: done
        context.insert(ReadingPlan(
            bookName: "Ruth",
            totalChapters: 4,
            status: .done,
            plannedDays: 4,
            startDate: daysAgo(20),
            finishedDate: daysAgo(16),
            chaptersRead: [1, 2, 3, 4]
        ))

        // Services across September and October 2026
        let s1 = Service(
            date: date(2026, 9, 20, 9, 0),
            gatheringName: "Sunday worship",
            sermonTitle: "Trusting God in the waiting",
            sermonist: "Pastor Mensah",
            sermonNote: AttributedString("Waiting is not wasted time. God is working while we wait."),
            sermonFavourite: true
        )
        context.insert(s1)
        let s1v = verse("Proverbs", 3, 5, 6,
            "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
            part: .sermon)
        context.insert(s1v)
        s1v.service = s1
        addSongs(to: s1, context: context, songs: [("12", "Great is thy faithfulness"), ("245", "Blessed assurance")])

        let s2 = Service(
            date: date(2026, 9, 22, 18, 30),
            gatheringName: "Bible study",
            classLesson: "The fruit of the Spirit",
            classTeacher: "Elder Boateng",
            classNote: AttributedString("Fruit grows over time. It is the Spirit's work in us, not our effort alone."),
            classFavourite: true
        )
        context.insert(s2)
        let s2v = verse("Romans", 8, 28, 28,
            "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
            part: .bibleClass)
        context.insert(s2v)
        s2v.service = s2
        addSongs(to: s2, context: context, songs: [("78", "Holy Spirit, light divine")])

        let s3 = Service(
            date: date(2026, 9, 27, 9, 0),
            gatheringName: "Sunday worship",
            sermonTitle: "Fear not",
            sermonist: "Pastor Mensah",
            sermonNote: AttributedString("God says fear not because he is with us. His presence answers every fear."),
            classLesson: "Prayer that changes us",
            classTeacher: "Sister Adjei",
            classNote: AttributedString("Prayer shapes the one who prays.")
        )
        context.insert(s3)
        let s3v = verse("Isaiah", 41, 10, 10,
            "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.",
            part: .sermon)
        context.insert(s3v)
        s3v.service = s3
        addSongs(to: s3, context: context, songs: [("12", "Great is thy faithfulness"), ("301", "It is well with my soul"), ("56", "How firm a foundation")])

        let s4 = Service(
            date: date(2026, 10, 4, 9, 0),
            gatheringName: "Sunday worship",
            sermonTitle: "Seek first the kingdom",
            sermonist: "Pastor Owusu",
            sermonNote: AttributedString("Priorities decide what we worry about. Seek him first and the rest follows."),
            sermonFavourite: true,
            classLesson: "Faith that acts",
            classTeacher: "Elder Boateng",
            classNote: AttributedString("Faith is trusting what we cannot see, then acting on it.")
        )
        context.insert(s4)
        let s4a = verse("Matthew", 6, 33, 33,
            "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.",
            part: .sermon)
        let s4b = verse("Hebrews", 11, 1, 1,
            "Now faith is the substance of things hoped for, the evidence of things not seen.",
            part: .bibleClass)
        context.insert(s4a)
        context.insert(s4b)
        s4a.service = s4
        s4b.service = s4
        addSongs(to: s4, context: context, songs: [("245", "Blessed assurance"), ("56", "How firm a foundation")])

        let s5 = Service(
            date: date(2026, 10, 11, 9, 0),
            gatheringName: "Sunday worship",
            sermonTitle: "New every morning",
            sermonist: "Pastor Mensah",
            sermonNote: AttributedString("Mercy does not run out. Each day starts with a fresh supply."),
            classLesson: "Confession and cleansing",
            classTeacher: "Sister Adjei",
            classNote: AttributedString("Confessing is agreeing with God. He forgives and cleans.")
        )
        context.insert(s5)
        let s5a = verse("Lamentations", 3, 22, 23,
            "It is of the Lord’s mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.",
            part: .sermon)
        let s5b = verse("1 John", 1, 9, 9,
            "If we confess our sins, he is faithful and just to forgive us our sins, and to cleanse us from all unrighteousness.",
            part: .bibleClass)
        context.insert(s5a)
        context.insert(s5b)
        s5a.service = s5
        s5b.service = s5
        addSongs(to: s5, context: context, songs: [("12", "Great is thy faithfulness"), ("301", "It is well with my soul")])

        // Personal notes
        let n1 = PersonalNote(
            title: "Prayer list",
            body: AttributedString("Mum's health. My exams. The youth camp. Wisdom for the week."),
            colour: .mint,
            pinned: true,
            updatedAt: daysAgo(1)
        )
        context.insert(n1)
        let n1v = verse("Philippians", 4, 6, 7,
            "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God. And the peace of God, which passeth all understanding, shall keep your hearts and minds through Christ Jesus.")
        context.insert(n1v)
        n1v.personalNote = n1

        context.insert(PersonalNote(
            title: "Questions to ask",
            body: AttributedString("What does it mean to be sealed by the Spirit? How should I read Revelation?"),
            colour: .sky,
            updatedAt: daysAgo(3)
        ))

        context.insert(PersonalNote(
            title: "Hymns to learn",
            body: AttributedString("It is well with my soul. How firm a foundation. Blessed assurance."),
            colour: .peach,
            updatedAt: daysAgo(5)
        ))

        let n4 = PersonalNote(
            title: "Verse for hard days",
            body: AttributedString("Read this slowly when things feel heavy."),
            colour: .sage,
            updatedAt: daysAgo(8)
        )
        context.insert(n4)
        let n4v = verse("Psalms", 46, 1, 1, "God is our refuge and strength, a very present help in trouble.")
        context.insert(n4v)
        n4v.personalNote = n4

        try? context.save()
    }

    private static func addSongs(to service: Service, context: ModelContext, songs: [(String, String)]) {
        for (index, item) in songs.enumerated() {
            let song = Song(hymnNumber: item.0, title: item.1, order: index)
            context.insert(song)
            song.service = service
        }
    }
}
