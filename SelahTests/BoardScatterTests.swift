import Foundation
import Testing
@testable import Selah

struct BoardScatterTests {
    @Test func scatterStaysWithinTheLimits() {
        for index in 0..<300 {
            let scatter = StickyStyle.scatter(seed: "note \(index)")
            #expect(abs(scatter.rotation) >= 1.4)
            #expect(abs(scatter.rotation) <= 4.0)
            #expect(abs(scatter.dx) <= 6)
            #expect(abs(scatter.dy) <= 6)
            #expect(abs(scatter.attachmentAngle) <= 8)
        }
    }

    @Test func scatterIsStableForTheSameSeed() {
        #expect(StickyStyle.scatter(seed: "Sermon on hope") == StickyStyle.scatter(seed: "Sermon on hope"))
    }

    @Test func scatterVariesAndUsesAllThreeAttachments() {
        let all = (0..<100).map { StickyStyle.scatter(seed: "note \($0)") }
        #expect(Set(all.map { $0.rotation }).count > 50)
        #expect(Set(all.map { String(describing: $0.attachment) }).count == 3)
    }

    @Test func pinnedNotesAlwaysGetAPin() {
        for index in 0..<100 {
            #expect(StickyStyle.scatter(seed: "note \(index)", pinned: true).attachment == .pin)
        }
    }

    @Test func readingOrderGoesTopToBottomAcrossColumns() {
        // Left column: items 0 (100 tall), 2. Right column (pushed down 28): items 1 (50 tall), 3.
        let order = StickyStyle.readingOrder(
            columns: [[0, 2], [1, 3]],
            heights: [100, 50, 80, 80],
            columnOffsets: [0, 28]
        )
        // Tops: item0 0, item1 28, item2 100, item3 78.
        #expect(order == [0, 1, 3, 2])
    }

    @Test func readingOrderBreaksTiesLeftFirst() {
        let order = StickyStyle.readingOrder(columns: [[0], [1]], heights: [10, 10])
        #expect(order == [0, 1])
    }

    @Test func readMinutesRoundsUpAndIsAtLeastOne() {
        #expect(StickyStyle.readMinutes(wordCount: 0) == 1)
        #expect(StickyStyle.readMinutes(wordCount: 200) == 1)
        #expect(StickyStyle.readMinutes(wordCount: 201) == 2)
        #expect(StickyStyle.readMinutes(wordCount: 640) == 4)
    }

    @Test func attributedStringCountsWordsAndHighlights() {
        var text = AttributedString("Hope is an anchor for the soul")
        let range = text.range(of: "anchor")!
        text[range][HighlightIDAttribute.self] = "h1"
        let other = text.range(of: "soul")!
        text[other][HighlightIDAttribute.self] = "h2"
        #expect(text.wordCount == 7)
        #expect(text.highlightCount == 2)
    }
}
