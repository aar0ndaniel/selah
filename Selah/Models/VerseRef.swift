import Foundation
import SwiftData

@Model
final class VerseRef {
    var book: String = ""
    var chapter: Int = 1
    var verseStart: Int = 1
    var verseEnd: Int = 1
    var translation: Translation = Translation.kjv
    /// Verse text at the time it was added, so old notes still read correctly.
    var textSnapshot: String = ""
    var part: VersePart = VersePart.none

    var studyEntry: StudyEntry?
    var service: Service?
    var personalNote: PersonalNote?

    init(
        book: String = "",
        chapter: Int = 1,
        verseStart: Int = 1,
        verseEnd: Int = 1,
        translation: Translation = .kjv,
        textSnapshot: String = "",
        part: VersePart = .none
    ) {
        self.book = book
        self.chapter = chapter
        self.verseStart = verseStart
        self.verseEnd = verseEnd
        self.translation = translation
        self.textSnapshot = textSnapshot
        self.part = part
    }

    /// For example "Philippians 4:6-7" or "John 3:16".
    var reference: String {
        if verseEnd > verseStart {
            return "\(book) \(chapter):\(verseStart)-\(verseEnd)"
        }
        return "\(book) \(chapter):\(verseStart)"
    }
}
