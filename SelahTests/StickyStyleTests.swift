import Foundation
import Testing
@testable import Selah

struct StickyStyleTests {
    @Test func rotationStaysWithinOneAndAHalfDegrees() {
        for index in 0..<200 {
            let value = StickyStyle.rotation(seed: "note \(index)")
            #expect(value >= -1.5)
            #expect(value <= 1.5)
        }
    }

    @Test func rotationIsStableForTheSameSeed() {
        #expect(StickyStyle.rotation(seed: "Sermon on hope") == StickyStyle.rotation(seed: "Sermon on hope"))
    }

    @Test func rotationVariesBetweenNotes() {
        let values = Set((0..<20).map { StickyStyle.rotation(seed: "note \($0)") })
        #expect(values.count > 5)
    }

    @Test func splitAddsToTheShortestColumnAndKeepsOrder() {
        let columns = StickyStyle.split(heights: [100, 100, 100, 100, 50], columns: 2)
        #expect(columns == [[0, 2, 4], [1, 3]])
    }

    @Test func splitBalancesATallCard() {
        let columns = StickyStyle.split(heights: [300, 100, 100, 100], columns: 2)
        #expect(columns == [[0], [1, 2, 3]])
    }

    @Test func splitWithOneColumnKeepsEverything() {
        #expect(StickyStyle.split(heights: [10, 20, 30], columns: 1) == [[0, 1, 2]])
        #expect(StickyStyle.split(heights: [], columns: 2) == [[], []])
    }

    @Test func bookToneIsStableAndNeverSky() {
        for name in ["Philippians", "John", "Psalms", "1 Corinthians", "Genesis", ""] {
            #expect(StickyStyle.tone(forBook: name) == StickyStyle.tone(forBook: name))
            #expect(StickyStyle.tone(forBook: name) != .sky)
        }
    }
}
