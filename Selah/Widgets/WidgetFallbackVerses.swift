import Foundation

/// Well-loved short verses (KJV, public domain) built into the widgets, so the verse widget always has a verse even
/// before the app has shared one. Text copied from the bundled bible.sqlite.
enum WidgetFallbackVerses {
    static let all: [WidgetVerse] = [
        WidgetVerse(date: .distantPast, text: "For God so loved the world, that he gave his only begotten Son, that whosoever believeth in him should not perish, but have everlasting life.", reference: "John 3:16 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "I can do all things through Christ which strengtheneth me.", reference: "Philippians 4:13 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Trust in the Lord with all thine heart; and lean not unto thine own understanding.", reference: "Proverbs 3:5 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Have not I commanded thee? Be strong and of a good courage; be not afraid, neither be thou dismayed: for the Lord thy God is with thee whithersoever thou goest.", reference: "Joshua 1:9 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "But they that wait upon the Lord shall renew their strength; they shall mount up with wings as eagles; they shall run, and not be weary; and they shall walk, and not faint.", reference: "Isaiah 40:31 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Thy word is a lamp unto my feet, and a light unto my path.", reference: "Psalm 119:105 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "And we know that all things work together for good to them that love God, to them who are the called according to his purpose.", reference: "Romans 8:28 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "But seek ye first the kingdom of God, and his righteousness; and all these things shall be added unto you.", reference: "Matthew 6:33 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "For I know the thoughts that I think toward you, saith the Lord, thoughts of peace, and not of evil, to give you an expected end.", reference: "Jeremiah 29:11 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "The Lord is my shepherd; I shall not want.", reference: "Psalm 23:1 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "For God hath not given us the spirit of fear; but of power, and of love, and of a sound mind.", reference: "2 Timothy 1:7 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Now faith is the substance of things hoped for, the evidence of things not seen.", reference: "Hebrews 11:1 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Casting all your care upon him; for he careth for you.", reference: "1 Peter 5:7 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Delight thyself also in the Lord; and he shall give thee the desires of thine heart.", reference: "Psalm 37:4 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Rejoicing in hope; patient in tribulation; continuing instant in prayer;", reference: "Romans 12:12 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "And whatsoever ye do, do it heartily, as to the Lord, and not unto men;", reference: "Colossians 3:23 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "Be careful for nothing; but in every thing by prayer and supplication with thanksgiving let your requests be made known unto God.", reference: "Philippians 4:6 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "This is the day which the Lord hath made; we will rejoice and be glad in it.", reference: "Psalm 118:24 (KJV)", chosen: false),
        WidgetVerse(date: .distantPast, text: "They are new every morning: great is thy faithfulness.", reference: "Lamentations 3:23 (KJV)", chosen: false),
    ]

    /// The same verse all day, a different one each day.
    static func verse(on date: Date, calendar: Calendar = .current) -> WidgetVerse {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        var verse = all[day % all.count]
        verse.date = calendar.startOfDay(for: date)
        return verse
    }
}
