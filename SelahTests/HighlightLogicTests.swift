import Foundation
import Testing
@testable import Selah

struct HighlightLogicTests {
    private func highlighted(_ phrase: String, id: String, in string: String) -> AttributedString {
        var text = AttributedString(string)
        let range = text.range(of: phrase)!
        HighlightLogic.apply(id: id, to: range, in: &text)
        return text
    }

    @Test func applyMakesIDPresent() {
        let text = highlighted("brave", id: "a", in: "Hello brave new world")
        #expect(HighlightLogic.ids(in: text) == ["a"])
        #expect(HighlightLogic.orderedIDs(in: text) == ["a"])
        #expect(String(text.characters) == "Hello brave new world")
    }

    @Test func segmentsSplitAroundHighlight() {
        let text = highlighted("brave", id: "a", in: "Hello brave new world")
        let segments = HighlightLogic.segments(of: text)
        #expect(segments == [
            HighlightLogic.Segment(string: "Hello ", highlightID: nil),
            HighlightLogic.Segment(string: "brave", highlightID: "a"),
            HighlightLogic.Segment(string: " new world", highlightID: nil)
        ])
    }

    @Test func removeMakesIDAbsent() {
        var text = highlighted("brave", id: "a", in: "Hello brave new world")
        HighlightLogic.removeHighlight(id: "a", from: &text)
        #expect(HighlightLogic.ids(in: text).isEmpty)
        #expect(String(text.characters) == "Hello brave new world")
    }

    @Test func removeKeepsOtherHighlights() {
        var text = highlighted("brave", id: "a", in: "Hello brave new world")
        let range = text.range(of: "world")!
        HighlightLogic.apply(id: "b", to: range, in: &text)
        HighlightLogic.removeHighlight(id: "a", from: &text)
        #expect(HighlightLogic.ids(in: text) == ["b"])
    }

    @Test func deletingHighlightedTextLeavesOrphan() {
        var text = highlighted("brave", id: "a", in: "Hello brave new world")
        let range = text.range(of: "world")!
        HighlightLogic.apply(id: "b", to: range, in: &text)

        let doomed = text.range(of: "brave")!
        text.replaceSubrange(doomed, with: AttributedString())

        let orphaned = HighlightLogic.orphanedIDs(commentIDs: ["a", "b"], in: text)
        #expect(orphaned == ["a"])
    }

    @Test func noOrphansWhenAllHighlightsRemain() {
        let text = highlighted("brave", id: "a", in: "Hello brave new world")
        #expect(HighlightLogic.orphanedIDs(commentIDs: ["a"], in: text).isEmpty)
    }

    @Test func orderedIDsFollowReadingOrder() {
        var text = highlighted("world", id: "late", in: "Hello brave new world")
        let early = text.range(of: "Hello")!
        HighlightLogic.apply(id: "early", to: early, in: &text)
        #expect(HighlightLogic.orderedIDs(in: text) == ["early", "late"])
    }

    @Test func roundTripThroughRichTextCodingKeepsIDs() {
        let text = highlighted("brave", id: "a", in: "Hello brave new world")
        let decoded = RichTextCoding.decode(RichTextCoding.encode(text))
        #expect(HighlightLogic.ids(in: decoded) == ["a"])
        #expect(String(decoded.characters) == "Hello brave new world")
        #expect(HighlightLogic.segments(of: decoded) == HighlightLogic.segments(of: text))
    }

    @Test func segmentsRoundTripToAttributedString() {
        let text = highlighted("brave", id: "a", in: "Hello brave new world")
        let rebuilt = HighlightLogic.attributedString(from: HighlightLogic.segments(of: text))
        #expect(HighlightLogic.segments(of: rebuilt) == HighlightLogic.segments(of: text))
    }

    @MainActor
    @Test func textViewBridgeKeepsWordsAndHighlights() {
        let text = highlighted("brave", id: "a", in: "Hello brave new world")
        let ns = HighlightBridge.nsAttributedString(from: text)
        #expect(ns.string == "Hello brave new world")
        let back = HighlightBridge.attributedString(from: ns)
        #expect(HighlightLogic.segments(of: back) == HighlightLogic.segments(of: text))
    }
}
