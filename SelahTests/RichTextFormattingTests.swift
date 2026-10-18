import Foundation
import Testing
import UIKit
@testable import Selah

struct RichTextFormattingTests {
    // MARK: Helpers

    private func seg(
        _ string: String,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        strike: Bool = false,
        block: BlockStyle? = nil,
        id: String? = nil
    ) -> RichSegment {
        var format = RichFormat()
        format.bold = bold
        format.italic = italic
        format.underline = underline
        format.strikethrough = strike
        format.block = block
        format.highlightID = id
        return RichSegment(string: string, format: format)
    }

    private var sample: [RichSegment] {
        [
            seg("Title\n", block: .heading),
            seg("plain "),
            seg("bold", bold: true),
            seg(" "),
            seg("italic", italic: true),
            seg(" "),
            seg("all", bold: true, italic: true, underline: true),
            seg(" "),
            seg("marked", bold: true, id: "a"),
            seg("\n"),
            seg("\u{2022} item\n", block: .bullet),
            seg("1. first\n2. second\n", block: .numbered),
            seg("said it", italic: true, strike: true, block: .quote)
        ]
    }

    // MARK: Storage

    @Test func formattingSurvivesCodingRoundTrip() {
        let text = RichTextFormatting.attributedString(from: sample)
        let decoded = RichTextCoding.decode(RichTextCoding.encode(text))
        #expect(String(decoded.characters) == String(text.characters))
        #expect(RichTextFormatting.segments(of: decoded) == RichTextFormatting.segments(of: text))
        #expect(RichTextFormatting.segments(of: decoded) == sample)
    }

    @Test func oldPlainAndHighlightDataDecodesUnchanged() {
        var text = AttributedString("Hello brave new world")
        let range = text.range(of: "brave")!
        HighlightLogic.apply(id: "a", to: range, in: &text)
        let decoded = RichTextCoding.decode(RichTextCoding.encode(text))
        #expect(RichTextFormatting.segments(of: decoded) == [
            seg("Hello "),
            seg("brave", id: "a"),
            seg(" new world")
        ])
        #expect(HighlightLogic.segments(of: decoded) == HighlightLogic.segments(of: text))
    }

    @Test func highlightLogicWorksOnFormattedText() {
        var text = RichTextFormatting.attributedString(from: sample)
        #expect(HighlightLogic.ids(in: text) == ["a"])
        HighlightLogic.removeHighlight(id: "a", from: &text)
        #expect(HighlightLogic.ids(in: text).isEmpty)
        // The bold the highlighted word also had is still there.
        let segments = RichTextFormatting.segments(of: text)
        #expect(segments.contains(where: { $0.string.contains("marked") && $0.format.bold }))
    }

    @Test func plainTextDropsFormattingAndKeepsListMarkers() {
        let text = RichTextFormatting.attributedString(from: [
            seg("Plan\n", bold: true, block: .heading),
            seg("\u{2022} one\n", block: .bullet),
            seg("1. two", italic: true, block: .numbered)
        ])
        #expect(RichTextFormatting.plainText(of: text) == "Plan\n\u{2022} one\n1. two")
    }

    @Test func displayKeepsWordsAndBold() {
        let text = RichTextFormatting.attributedString(from: sample)
        let display = text.highlightedForDisplay()
        #expect(String(display.characters) == String(text.characters))
        #expect(display.runs.contains(where: { $0.inlinePresentationIntent?.contains(.stronglyEmphasized) == true }))
    }

    // MARK: Text view bridge

    @MainActor
    @Test func bridgeRoundTripKeepsFormattingAndHighlights() {
        let text = RichTextFormatting.attributedString(from: sample)
        let ns = HighlightBridge.nsAttributedString(from: text)
        #expect(ns.string == String(text.characters))
        let back = HighlightBridge.attributedString(from: ns)
        #expect(RichTextFormatting.segments(of: back) == sample)
        #expect(HighlightLogic.segments(of: back) == HighlightLogic.segments(of: text))
    }

    @MainActor
    @Test func bridgeDrawsFormattingWithFonts() {
        let text = RichTextFormatting.attributedString(from: [
            seg("bold", bold: true),
            seg("italic", italic: true),
            seg("under", underline: true),
            seg("mark", id: "x")
        ])
        let ns = HighlightBridge.nsAttributedString(from: text)
        let bold = ns.attribute(.font, at: 0, effectiveRange: nil) as? UIFont
        #expect(bold?.fontDescriptor.symbolicTraits.contains(.traitBold) == true)
        let italic = ns.attribute(.font, at: 4, effectiveRange: nil) as? UIFont
        #expect(italic?.fontDescriptor.symbolicTraits.contains(.traitItalic) == true)
        #expect(ns.attribute(.underlineStyle, at: 10, effectiveRange: nil) != nil)
        #expect(ns.attribute(.backgroundColor, at: 15, effectiveRange: nil) != nil)
        #expect(ns.attribute(.selahHighlightID, at: 15, effectiveRange: nil) as? String == "x")
    }

    @MainActor
    @Test func fontsAreNotReadBackAsUserFormatting() {
        // A heading is drawn semibold and a quote italic, but neither becomes stored bold or italic.
        let text = RichTextFormatting.attributedString(from: [
            seg("Head\n", block: .heading),
            seg("Quote", block: .quote)
        ])
        let back = HighlightBridge.attributedString(from: HighlightBridge.nsAttributedString(from: text))
        let segments = RichTextFormatting.segments(of: back)
        #expect(segments.allSatisfy { !$0.format.bold && !$0.format.italic })
        #expect(segments.map(\.format.block) == [.heading, .quote])
    }

    // MARK: Inline toggling

    @Test func togglingBoldOnARange() {
        let model = RichTextBridge.model(from: [seg("Hello brave world")])
        let on = RichTextOps.toggleInline(.bold, in: model, range: NSRange(location: 6, length: 5))
        #expect(on)
        #expect(RichTextBridge.segments(from: model) == [
            seg("Hello "),
            seg("brave", bold: true),
            seg(" world")
        ])
        #expect(RichTextOps.inlineState(.bold, in: model, range: NSRange(location: 6, length: 5)))
        #expect(!RichTextOps.inlineState(.bold, in: model, range: NSRange(location: 0, length: 11)))

        let off = RichTextOps.toggleInline(.bold, in: model, range: NSRange(location: 6, length: 5))
        #expect(!off)
        #expect(RichTextBridge.segments(from: model) == [seg("Hello brave world")])
    }

    @Test func togglingOnMixedRangeTurnsStyleOnEverywhere() {
        let model = RichTextBridge.model(from: [seg("ab", bold: true), seg("cd")])
        RichTextOps.toggleInline(.bold, in: model, range: NSRange(location: 0, length: 4))
        #expect(RichTextBridge.segments(from: model) == [seg("abcd", bold: true)])
    }

    @Test func inlineStyleSkipsListMarkers() {
        let model = RichTextBridge.model(from: [seg("\u{2022} one\n", block: .bullet)])
        RichTextOps.toggleInline(.italic, in: model, range: NSRange(location: 0, length: model.length))
        let segments = RichTextBridge.segments(from: model)
        #expect(segments.first?.string == "\u{2022} ")
        #expect(segments.first?.format.italic == false)
        #expect(segments.contains(where: { $0.string == "one" && $0.format.italic }))
    }

    // MARK: Blocks and lists

    @Test func bulletedListToggleAddsAndRemovesMarkers() {
        let model = RichTextBridge.model(from: [seg("one\ntwo")])
        var selection = NSRange(location: 0, length: 7)
        let result = RichTextOps.toggleBlock(.bullet, in: model, selection: &selection)
        #expect(result == .bullet)
        #expect(model.string == "\u{2022} one\n\u{2022} two")
        #expect(RichTextBridge.segments(from: model) == [seg("\u{2022} one\n\u{2022} two", block: .bullet)])

        let removed = RichTextOps.toggleBlock(.bullet, in: model, selection: &selection)
        #expect(removed == nil)
        #expect(model.string == "one\ntwo")
        #expect(RichTextBridge.segments(from: model) == [seg("one\ntwo")])
    }

    @Test func numberedListRenumbersAfterInsertAndDelete() {
        let model = RichTextBridge.model(from: [
            seg("1. a\n", block: .numbered),
            seg("1. b\n", block: .numbered),
            seg("1. c", block: .numbered)
        ])
        var selection = NSRange(location: 0, length: 0)
        #expect(RichTextOps.normalize(model, selection: &selection))
        #expect(model.string == "1. a\n2. b\n3. c")

        // Delete the middle item: numbers close the gap.
        model.deleteCharacters(in: NSRange(location: 5, length: 5))
        RichTextOps.normalize(model, selection: &selection)
        #expect(model.string == "1. a\n2. c")

        // Nothing left to fix.
        #expect(!RichTextOps.normalize(model, selection: &selection))
    }

    @Test func numberingRestartsAfterAPlainParagraph() {
        let model = RichTextBridge.model(from: [
            seg("1. a\n", block: .numbered),
            seg("break\n"),
            seg("5. b", block: .numbered)
        ])
        var selection = NSRange(location: 0, length: 0)
        RichTextOps.normalize(model, selection: &selection)
        #expect(model.string == "1. a\nbreak\n1. b")
    }

    @Test func normalizeAddsMissingMarkerAndKeepsCaretAfterIt() {
        let model = RichTextBridge.model(from: [seg("one\ntwo", block: .bullet)])
        var selection = NSRange(location: 2, length: 0)
        RichTextOps.normalize(model, selection: &selection)
        #expect(model.string == "\u{2022} one\n\u{2022} two")
        #expect(selection == NSRange(location: 4, length: 0))
    }

    @Test func numberedToggleOnTwoLines() {
        let model = RichTextBridge.model(from: [seg("one\ntwo\nthree")])
        var selection = NSRange(location: 0, length: 7)
        RichTextOps.toggleBlock(.numbered, in: model, selection: &selection)
        #expect(model.string == "1. one\n2. two\nthree")
    }

    @Test func headingAndQuoteHaveNoMarker() {
        let model = RichTextBridge.model(from: [seg("Title")])
        var selection = NSRange(location: 0, length: 0)
        #expect(RichTextOps.toggleBlock(.heading, in: model, selection: &selection) == .heading)
        #expect(RichTextBridge.segments(from: model) == [seg("Title", block: .heading)])
        #expect(RichTextOps.blockState(.heading, in: model, selection: selection))

        // Switching from heading to bullets replaces the style.
        #expect(RichTextOps.toggleBlock(.bullet, in: model, selection: &selection) == .bullet)
        #expect(model.string == "\u{2022} Title")
        #expect(RichTextOps.blockState(.bullet, in: model, selection: selection))
        #expect(!RichTextOps.blockState(.heading, in: model, selection: selection))
    }

    @Test func renumberedHelperFixesStoredText() {
        let text = RichTextFormatting.attributedString(from: [
            seg("3. x\n", block: .numbered),
            seg("9. y", block: .numbered)
        ])
        let fixed = RichTextFormatting.renumbered(text)
        #expect(String(fixed.characters) == "1. x\n2. y")
    }

    @Test func paragraphRangesIncludeTrailingEmptyLine() {
        let ranges = RichTextOps.paragraphRanges(in: "a\nb\n" as NSString)
        #expect(ranges == [
            NSRange(location: 0, length: 2),
            NSRange(location: 2, length: 2),
            NSRange(location: 4, length: 0)
        ])
    }
}
