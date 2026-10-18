import Foundation

/// Well-loved passages shown in the verse picker before the user types anything.
enum PopularPassages {
    private static let texts: [String] = [
        "John 3:16",
        "Psalm 23",
        "Philippians 4:6-7",
        "Romans 8:28",
        "Proverbs 3:5-6",
        "Isaiah 40:31",
        "Jeremiah 29:11",
        "Matthew 6:33",
        "1 Corinthians 13:4-7",
        "Joshua 1:9",
        "Psalm 46:1",
        "2 Timothy 3:16"
    ]

    static let all: [BibleReference] = {
        let parser = ReferenceParser()
        return texts.compactMap { parser.parse($0) }
    }()
}
