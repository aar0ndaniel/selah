import Foundation
import SQLite3

/// SQLite's "copy this string" destructor. Not imported into Swift, so defined here.
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

/// One verse of a passage.
struct Verse: Sendable, Hashable {
    let number: Int
    let text: String
}

/// Read-only lookup into the bundled bible.sqlite. Fails soft: if the file is missing
/// or a query fails, results are empty.
final class BibleStore: @unchecked Sendable {
    static let shared: BibleStore = {
        BibleStore(path: Bundle.main.path(forResource: "bible", ofType: "sqlite"))
    }()

    private let lock = NSLock()
    private var db: OpaquePointer?

    private enum Bind {
        case int(Int)
        case text(String)
    }

    init(path: String?) {
        guard let path else { return }
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(path, &handle, flags, nil) == SQLITE_OK {
            db = handle
        } else if let handle {
            sqlite3_close(handle)
        }
    }

    deinit {
        if let db {
            sqlite3_close(db)
        }
    }

    /// True when the database file was found and opened.
    var isAvailable: Bool {
        lock.lock()
        defer { lock.unlock() }
        return db != nil
    }

    /// Database code for a translation. Mapped explicitly because the enum raw values are lowercase.
    static func code(for translation: Translation) -> String {
        switch translation {
        case .kjv: return "KJV"
        case .asv: return "ASV"
        case .web: return "WEB"
        case .bsb: return "BSB"
        }
    }

    func chapterCount(bookID: Int) -> Int {
        BibleBooks.chapterCount(for: bookID) ?? 0
    }

    /// Verses for a reference. Verses missing from a translation are simply left out.
    func verses(for ref: BibleReference, translation: Translation) -> [Verse] {
        var sql = "SELECT verse, text FROM verses WHERE translation = ? AND book = ? AND chapter = ?"
        var binds: [Bind] = [.text(Self.code(for: translation)), .int(ref.bookID), .int(ref.chapter)]
        if let start = ref.verseStart {
            sql += " AND verse BETWEEN ? AND ?"
            binds.append(.int(start))
            binds.append(.int(max(start, ref.verseEnd ?? start)))
        }
        sql += " ORDER BY verse"
        return run(sql, binds: binds)
    }

    /// Passage text. One verse is returned plain; several verses get their numbers in front.
    func text(for ref: BibleReference, translation: Translation) -> String {
        Self.joined(verses(for: ref, translation: translation))
    }

    static func joined(_ verses: [Verse]) -> String {
        if verses.count == 1, let only = verses.first { return only.text }
        return verses.map { "\($0.number) \($0.text)" }.joined(separator: " ")
    }

    // MARK: Query

    private func run(_ sql: String, binds: [Bind]) -> [Verse] {
        lock.lock()
        defer { lock.unlock() }
        guard let db else { return [] }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            return []
        }
        defer { sqlite3_finalize(statement) }

        for (offset, bind) in binds.enumerated() {
            let index = Int32(offset + 1)
            switch bind {
            case .int(let value):
                sqlite3_bind_int64(statement, index, Int64(value))
            case .text(let value):
                sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
            }
        }

        var result: [Verse] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            let number = Int(sqlite3_column_int64(statement, 0))
            var text = ""
            if let cString = sqlite3_column_text(statement, 1) {
                text = String(cString: cString)
            }
            result.append(Verse(number: number, text: text))
        }
        return result
    }
}
