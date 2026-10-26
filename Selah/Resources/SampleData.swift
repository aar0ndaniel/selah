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
        ServicePart.self,
        LibrarySong.self,
        PersonalNote.self,
        VerseRef.self,
        NoteComment.self,
        MoodEntry.self
    ]

    static let container: ModelContainer = makeContainer(seeded: true)

    /// A fresh in-memory store. Used by previews (seeded) and by UI-test launches (`-uiTestSampleData` is seeded,
    /// `-uiTestOnboarding` is empty so the first-launch flow shows).
    static func makeContainer(seeded: Bool) -> ModelContainer {
        do {
            let schema = Schema(allModels)
            let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [configuration])
            if seeded { seed(container.mainContext) }
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

    // MARK: - Seed

    /// Fills a context with the sample profile (onboarded), meeting days, books, services and notes.
    static func seed(_ context: ModelContext) {
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

        // Song library (public-domain lyrics only)
        let library = seedLibrary(context)

        // Services across September and October 2026, recorded as parts in the order they happened
        let s1 = newService(context, date(2026, 9, 20, 9, 0), "Sunday worship")
        addSong(to: s1, context, .hymn, "12", "Great is thy faithfulness", library)
        addTalk(.sermon, to: s1, context,
                title: "Trusting God in the waiting", person: "Pastor Mensah",
                note: "Waiting is not wasted time. God is working while we wait.", favourite: true,
                verses: [verse("Proverbs", 3, 5, 6,
                    "Trust in the Lord with all thine heart; and lean not unto thine own understanding. In all thy ways acknowledge him, and he shall direct thy paths.",
                    part: .sermon)])
        addSong(to: s1, context, .hymn, "245", "Blessed assurance", library)

        let s2 = newService(context, date(2026, 9, 22, 18, 30), "Bible study")
        addSong(to: s2, context, .hymn, "78", "Holy Spirit, light divine", library)
        addTalk(.bibleClass, to: s2, context,
                title: "The fruit of the Spirit", person: "Elder Boateng",
                note: "Fruit grows over time. It is the Spirit's work in us, not our effort alone.", favourite: true,
                verses: [verse("Romans", 8, 28, 28,
                    "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.",
                    part: .bibleClass)])

        let s3 = newService(context, date(2026, 9, 27, 9, 0), "Sunday worship")
        addSong(to: s3, context, .chorus, "", "This is the day", library)
        addTalk(.bibleClass, to: s3, context,
                title: "Prayer that changes us", person: "Sister Adjei",
                note: "Prayer shapes the one who prays.")
        addSong(to: s3, context, .hymn, "12", "Great is thy faithfulness", library)
        addTalk(.sermon, to: s3, context,
                title: "Fear not", person: "Pastor Mensah",
                note: "God says fear not because he is with us. His presence answers every fear.",
                verses: [verse("Isaiah", 41, 10, 10,
                    "Fear thou not; for I am with thee: be not dismayed; for I am thy God: I will strengthen thee; yea, I will help thee; yea, I will uphold thee with the right hand of my righteousness.",
                    part: .sermon)])
        addSong(to: s3, context, .hymn, "301", "It is well with my soul", library)
        addSong(to: s3, context, .hymn, "56", "How firm a foundation", library)

        let s4 = newService(context, date(2026, 10, 4, 9, 0), "Sunday worship")
        addSong(to: s4, context, .worship, "", "Alpha and Omega", library)
        addTalk(.bibleClass, to: s4, context,
                title: "Faith that acts", person: "Elder Boateng",
                note: "Faith is trusting what we cannot see, then acting on it.",
                verses: [verse("Hebrews", 11, 1, 1,
                    "Now faith is the substance of things hoped for, the evidence of things not seen.",
                    part: .bibleClass)])
        addSong(to: s4, context, .hymn, "245", "Blessed assurance", library)
        addTalk(.sermon, to: s4, context,
                title: "Seek first the kingdom", person: "Pastor Owusu",
                note: "Priorities decide what we worry about. Seek him first and the rest follows.", favourite: true,
                verses: [verse("Matthew", 6, 33, 33,
                    "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.",
                    part: .sermon)])
        addSong(to: s4, context, .hymn, "56", "How firm a foundation", library)

        let s5 = newService(context, date(2026, 10, 11, 9, 0), "Sunday worship")
        addSong(to: s5, context, .hymn, "12", "Great is thy faithfulness", library)
        addTalk(.bibleClass, to: s5, context,
                title: "Confession and cleansing", person: "Sister Adjei",
                note: "Confessing is agreeing with God. He forgives and cleans.",
                verses: [verse("1 John", 1, 9, 9,
                    "If we confess our sins, he is faithful and just to forgive us our sins, and to cleanse us from all unrighteousness.",
                    part: .bibleClass)])
        addTalk(.sermon, to: s5, context,
                title: "New every morning", person: "Pastor Mensah",
                note: "Mercy does not run out. Each day starts with a fresh supply.",
                verses: [verse("Lamentations", 3, 22, 23,
                    "It is of the Lord’s mercies that we are not consumed, because his compassions fail not. They are new every morning: great is thy faithfulness.",
                    part: .sermon)])
        addSong(to: s5, context, .hymn, "301", "It is well with my soul", library)

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

        // Two earlier check-ins and none for today, so the daily check-in is due in a sample launch.
        context.insert(MoodEntry(date: daysAgo(1), mood: .peaceful, note: "A quiet morning with Psalm 46."))
        context.insert(MoodEntry(date: daysAgo(2), mood: .grateful, note: "Thankful for a good week."))

        try? context.save()
    }

    // MARK: - Service helpers

    private static func newService(_ context: ModelContext, _ date: Date, _ gathering: String) -> Service {
        let service = Service(date: date, gatheringName: gathering)
        service.partsMigrated = true
        context.insert(service)
        return service
    }

    private static func addTalk(
        _ kind: ServicePartKind,
        to service: Service,
        _ context: ModelContext,
        title: String,
        person: String,
        note: String,
        favourite: Bool = false,
        verses: [VerseRef] = []
    ) {
        let part = ServicePart(
            kind: kind,
            order: service.nextPartOrder,
            title: title,
            person: person,
            notes: AttributedString(note),
            isFavourite: favourite
        )
        context.insert(part)
        part.service = service
        for verse in verses {
            context.insert(verse)
            verse.servicePart = part
        }
    }

    private static func addSong(
        to service: Service,
        _ context: ModelContext,
        _ type: SongType,
        _ number: String,
        _ title: String,
        _ library: [String: LibrarySong]
    ) {
        let part = ServicePart(kind: .song, order: service.nextPartOrder, title: title, songType: type, hymnNumber: number)
        context.insert(part)
        part.service = service
        if let song = library[title] {
            part.librarySong = song
            if song.lastSungAt.map({ $0 < service.date }) ?? true { song.lastSungAt = service.date }
        }
    }

    /// Library songs keyed by title. "Blessed assurance" (Fanny Crosby, 1873) and "Amazing grace" (John Newton, 1779)
    /// carry public-domain lyrics so the Songs screens have something to show.
    private static func seedLibrary(_ context: ModelContext) -> [String: LibrarySong] {
        let logged: [(SongType, String, String)] = [
            (.hymn, "12", "Great is thy faithfulness"),
            (.hymn, "78", "Holy Spirit, light divine"),
            (.hymn, "301", "It is well with my soul"),
            (.hymn, "56", "How firm a foundation"),
            (.chorus, "", "This is the day"),
            (.worship, "", "Alpha and Omega")
        ]
        var result: [String: LibrarySong] = [:]
        for (type, number, title) in logged {
            let song = LibrarySong(title: title, songType: type, hymnNumber: number, source: .logged)
            context.insert(song)
            result[title] = song
        }

        let blessed = LibrarySong(
            title: "Blessed assurance",
            songType: .hymn,
            hymnNumber: "245",
            lyricVerses: [
                "Blessed assurance, Jesus is mine!\nO what a foretaste of glory divine!\nHeir of salvation, purchase of God,\nBorn of his Spirit, washed in his blood.",
                "Perfect submission, perfect delight,\nVisions of rapture now burst on my sight;\nAngels descending bring from above\nEchoes of mercy, whispers of love."
            ],
            refrain: "This is my story, this is my song,\nPraising my Saviour all the day long;\nThis is my story, this is my song,\nPraising my Saviour all the day long.",
            source: .logged
        )
        context.insert(blessed)
        result[blessed.title] = blessed

        let amazing = LibrarySong(
            title: "Amazing grace",
            songType: .hymn,
            lyricVerses: [
                "Amazing grace! how sweet the sound\nThat saved a wretch like me!\nI once was lost, but now am found,\nWas blind, but now I see.",
                "'Twas grace that taught my heart to fear,\nAnd grace my fears relieved;\nHow precious did that grace appear\nThe hour I first believed!"
            ],
            source: .added
        )
        context.insert(amazing)
        result[amazing.title] = amazing
        return result
    }
}
