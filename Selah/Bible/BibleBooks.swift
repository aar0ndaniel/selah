import Foundation

/// The 66 books in canonical order, with chapter counts and abbreviations.
/// Pure data: no database, no UI. Book ids are 1...66 and match `books.id` in bible.sqlite.
enum BibleBooks {
    static let names: [String] = [
        "Genesis", "Exodus", "Leviticus", "Numbers", "Deuteronomy",
        "Joshua", "Judges", "Ruth", "1 Samuel", "2 Samuel",
        "1 Kings", "2 Kings", "1 Chronicles", "2 Chronicles", "Ezra",
        "Nehemiah", "Esther", "Job", "Psalms", "Proverbs",
        "Ecclesiastes", "Song of Solomon", "Isaiah", "Jeremiah", "Lamentations",
        "Ezekiel", "Daniel", "Hosea", "Joel", "Amos",
        "Obadiah", "Jonah", "Micah", "Nahum", "Habakkuk",
        "Zephaniah", "Haggai", "Zechariah", "Malachi", "Matthew",
        "Mark", "Luke", "John", "Acts", "Romans",
        "1 Corinthians", "2 Corinthians", "Galatians", "Ephesians", "Philippians",
        "Colossians", "1 Thessalonians", "2 Thessalonians", "1 Timothy", "2 Timothy",
        "Titus", "Philemon", "Hebrews", "James", "1 Peter",
        "2 Peter", "1 John", "2 John", "3 John", "Jude",
        "Revelation"
    ]

    static let chapterCounts: [Int] = [
        50, 40, 27, 36, 34,
        24, 21, 4, 31, 24,
        22, 25, 29, 36, 10,
        13, 10, 42, 150, 31,
        12, 8, 66, 52, 5,
        48, 12, 14, 3, 9,
        1, 4, 7, 3, 3,
        3, 2, 14, 4, 28,
        16, 24, 21, 28, 16,
        16, 13, 6, 6, 4,
        4, 5, 3, 6, 4,
        3, 1, 13, 5, 5,
        3, 5, 1, 1, 1,
        22
    ]

    static func name(for bookID: Int) -> String? {
        guard bookID >= 1, bookID <= names.count else { return nil }
        return names[bookID - 1]
    }

    static func chapterCount(for bookID: Int) -> Int? {
        guard bookID >= 1, bookID <= chapterCounts.count else { return nil }
        return chapterCounts[bookID - 1]
    }

    /// Lowercases and removes spaces and dots: "1 Jn." becomes "1jn".
    static func key(_ text: String) -> String {
        var result = ""
        for ch in text.lowercased() where ch != " " && ch != "." && ch != "\u{00A0}" {
            result.append(ch)
        }
        return result
    }

    /// Finds a book id from a name or abbreviation, ignoring case, spaces and dots.
    static func bookID(forAlias alias: String) -> Int? {
        aliasMap[key(alias)]
    }

    // MARK: Abbreviations

    private static let plainAbbreviations: [(id: Int, aliases: [String])] = [
        (1, ["gen", "ge", "gn", "genesis"]),
        (2, ["ex", "exo", "exod", "exodus"]),
        (3, ["lev", "le", "lv", "leviticus"]),
        (4, ["num", "nu", "nm", "nb", "numbers"]),
        (5, ["deut", "dt", "de", "deu", "deuteronomy"]),
        (6, ["josh", "jos", "jsh", "joshua"]),
        (7, ["judg", "jdg", "jg", "jdgs", "judges"]),
        (8, ["ru", "rth", "ruth"]),
        (15, ["ezr", "ezra"]),
        (16, ["neh", "ne", "nehemiah"]),
        (17, ["est", "esth", "es", "esther"]),
        (18, ["job", "jb"]),
        (19, ["ps", "psa", "psalm", "pss", "psalms", "psm", "pslm"]),
        (20, ["prov", "pro", "prv", "pr", "proverbs"]),
        (21, ["eccl", "eccles", "ecc", "ec", "ecclesiastes", "qoh", "qoheleth"]),
        (22, ["song", "sos", "song of songs", "song of solomon", "canticles", "canticle of canticles", "ss", "sng"]),
        (23, ["isa", "is", "isaiah"]),
        (24, ["jer", "je", "jr", "jeremiah"]),
        (25, ["lam", "la", "lamentations"]),
        (26, ["ezek", "eze", "ezk", "ezekiel"]),
        (27, ["dan", "da", "dn", "daniel"]),
        (28, ["hos", "ho", "hosea"]),
        (29, ["joel", "joe", "jl"]),
        (30, ["am", "amos"]),
        (31, ["obad", "ob", "oba", "obadiah"]),
        (32, ["jonah", "jon", "jnh"]),
        (33, ["mic", "mi", "micah"]),
        (34, ["nah", "na", "nahum"]),
        (35, ["hab", "hb", "habakkuk"]),
        (36, ["zeph", "zep", "zp", "zephaniah"]),
        (37, ["hag", "hg", "haggai"]),
        (38, ["zech", "zec", "zc", "zechariah"]),
        (39, ["mal", "ml", "malachi"]),
        (40, ["matt", "mat", "mt", "matthew"]),
        (41, ["mark", "mrk", "mar", "mk", "mr"]),
        (42, ["luke", "luk", "lk"]),
        (43, ["john", "jn", "jhn", "joh"]),
        (44, ["acts", "act", "ac"]),
        (45, ["rom", "ro", "rm", "romans"]),
        (48, ["gal", "ga", "galatians"]),
        (49, ["eph", "ephes", "ephesians"]),
        (50, ["phil", "php", "pp", "philippians"]),
        (51, ["col", "co", "colossians"]),
        (56, ["titus", "tit"]),
        (57, ["philem", "phlm", "phm", "philemon"]),
        (58, ["heb", "hebrews"]),
        (59, ["jas", "jam", "jm", "james"]),
        (65, ["jude", "jud"]),
        (66, ["rev", "re", "rv", "revelation", "revelations", "revelation of john"])
    ]

    /// Books that come in numbered sets: ids in order (1st, 2nd, 3rd) and the shared name bases.
    private static let numberedGroups: [(ids: [Int], bases: [String])] = [
        ([9, 10], ["samuel", "sam", "sa", "sm"]),
        ([11, 12], ["kings", "kgs", "ki", "kin", "k"]),
        ([13, 14], ["chronicles", "chron", "chr", "ch"]),
        ([46, 47], ["corinthians", "cor", "co"]),
        ([52, 53], ["thessalonians", "thess", "thes", "th"]),
        ([54, 55], ["timothy", "tim", "ti"]),
        ([60, 61], ["peter", "pet", "pe", "pt"]),
        ([62, 63, 64], ["john", "jn", "jhn", "joh", "jo"])
    ]

    private static let romanPrefixes = ["i", "ii", "iii"]
    private static let ordinalPrefixes = ["1st", "2nd", "3rd"]
    private static let wordPrefixes = ["first", "second", "third"]

    /// Every accepted spelling (keys have no spaces or dots) mapped to a book id. First writer wins.
    static let aliasMap: [String: Int] = {
        var map: [String: Int] = [:]
        func add(_ alias: String, _ id: Int) {
            let k = key(alias)
            if !k.isEmpty, map[k] == nil { map[k] = id }
        }
        for (index, name) in names.enumerated() { add(name, index + 1) }
        for entry in plainAbbreviations {
            for alias in entry.aliases { add(alias, entry.id) }
        }
        for group in numberedGroups {
            for (index, id) in group.ids.enumerated() {
                let prefixes = ["\(index + 1)", romanPrefixes[index], ordinalPrefixes[index], wordPrefixes[index]]
                for prefix in prefixes {
                    for base in group.bases { add(prefix + base, id) }
                }
            }
        }
        return map
    }()

    /// Keys used for live suggestions: full names, plain abbreviations and "1"/"2"/"3" forms only.
    static let suggestionKeys: [(key: String, id: Int)] = {
        var result: [(key: String, id: Int)] = []
        for (index, name) in names.enumerated() { result.append((key: key(name), id: index + 1)) }
        for entry in plainAbbreviations {
            for alias in entry.aliases { result.append((key: key(alias), id: entry.id)) }
        }
        for group in numberedGroups {
            for (index, id) in group.ids.enumerated() {
                for base in group.bases { result.append((key: "\(index + 1)" + base, id: id)) }
            }
        }
        return result
    }()
}
