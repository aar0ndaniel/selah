import SwiftUI
import UIKit

/// Converts between the stored `AttributedString` and the text view's `NSAttributedString`.
///
/// Both directions go run by run through `RichSegment` (words plus bold, italic, underline, strikethrough, block
/// style and highlight ID), by hand, so nothing depends on automatic attribute bridging. The text view keeps the
/// same facts as custom attributes (see `RichTextFormatting.swift`); fonts, colours, underline and paragraph indents
/// are derived from them in `styled` and are never read back.
@MainActor
enum HighlightBridge {
    static var baseAttributes: [NSAttributedString.Key: Any] {
        styledAttributes(for: RichFormat())
    }

    static var highlightColor: UIColor {
        UIColor(named: "HighlightMint") ?? .systemMint
    }

    static func nsAttributedString(from text: AttributedString) -> NSAttributedString {
        styled(RichTextBridge.model(from: RichTextFormatting.segments(of: text)))
    }

    static func segments(from text: NSAttributedString) -> [RichSegment] {
        RichTextBridge.segments(from: text)
    }

    static func attributedString(from text: NSAttributedString) -> AttributedString {
        RichTextFormatting.attributedString(from: RichTextBridge.segments(from: text))
    }

    // MARK: Styling

    /// The text with fonts, colours, underline, indents and highlight background derived from its model attributes.
    static func styled(_ text: NSAttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let string = NSString(string: text.string)
        text.enumerateAttributes(in: NSRange(location: 0, length: text.length), options: []) { attributes, range, _ in
            result.append(
                NSAttributedString(
                    string: string.substring(with: range),
                    attributes: styledAttributes(for: RichFormat(attributes: attributes))
                )
            )
        }
        return result
    }

    /// Model attributes plus everything UIKit needs to draw them. Also used for the text view's typing attributes.
    static func styledAttributes(for format: RichFormat) -> [NSAttributedString.Key: Any] {
        var result = format.attributes
        result[.font] = font(for: format)
        result[.foregroundColor] = (format.block == .quote && format.highlightID == nil)
            ? UIColor.secondaryLabel
            : UIColor.label
        result[.paragraphStyle] = paragraphStyle(for: format.block)
        if format.underline {
            result[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if format.strikethrough {
            result[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if format.highlightID != nil {
            result[.backgroundColor] = highlightColor
        }
        return result
    }

    /// Body text follows Dynamic Type (preferred font at the current size). Headings are New York semibold at the
    /// title3 size. A quote is always italic. Bold and italic from the user add on top.
    static func font(for format: RichFormat) -> UIFont {
        if format.block == .heading {
            let base = NavigationAppearance.serifFont(for: .title3, weight: format.bold ? .bold : .semibold)
            guard format.italic else { return base }
            let traits = base.fontDescriptor.symbolicTraits.union(.traitItalic)
            if let descriptor = base.fontDescriptor.withSymbolicTraits(traits) {
                return UIFont(descriptor: descriptor, size: base.pointSize)
            }
            return base
        }
        let base = UIFont.preferredFont(forTextStyle: .body)
        var traits: UIFontDescriptor.SymbolicTraits = []
        if format.bold { traits.insert(.traitBold) }
        if format.italic || format.block == .quote { traits.insert(.traitItalic) }
        guard !traits.isEmpty, let descriptor = base.fontDescriptor.withSymbolicTraits(traits) else {
            return base
        }
        return UIFont(descriptor: descriptor, size: base.pointSize)
    }

    /// Lists hang their wrapped lines under the words, quotes are indented, headings get a little space above.
    static func paragraphStyle(for block: BlockStyle?) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        guard let block else { return style }
        let body = UIFont.preferredFont(forTextStyle: .body)
        switch block {
        case .bullet:
            let width = NSString(string: RichTextOps.listPrefix(for: .bullet, number: 1))
                .size(withAttributes: [.font: body]).width
            style.headIndent = ceil(width)
        case .numbered:
            let width = NSString(string: RichTextOps.listPrefix(for: .numbered, number: 8))
                .size(withAttributes: [.font: body]).width
            style.headIndent = ceil(width)
        case .quote:
            let indent = UIFontMetrics(forTextStyle: .body).scaledValue(for: 16)
            style.firstLineHeadIndent = indent
            style.headIndent = indent
        case .heading:
            style.paragraphSpacingBefore = UIFontMetrics(forTextStyle: .title3).scaledValue(for: 4)
        }
        return style
    }
}

/// Asks the text view to select a highlight and bring it into view.
struct RevealRequest: Equatable {
    let id: String
    let token = UUID()
}

/// A self-sizing UITextView with rich text support: bold, italic, underline, heading, lists, quote and highlight.
/// It is used because it gives exact control over selection, typing attributes and tap detection (see RichNoteEditor).
struct HighlightTextView: UIViewRepresentable {
    @Binding var text: AttributedString
    var placeholder: String
    var minHeight: CGFloat
    var reveal: RevealRequest?
    /// Called after the user edits the words, with the new text.
    var onEdit: (AttributedString) -> Void
    /// Called after a highlight was applied to the selection: its ID and the quoted words.
    var onHighlight: (String, String) -> Void
    /// Called when the user taps highlighted words.
    var onHighlightTap: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.textColor = .label
        textView.typingAttributes = HighlightBridge.baseAttributes
        textView.accessibilityLabel = placeholder
        textView.inputAccessoryView = context.coordinator.makeAccessory()
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        textView.addGestureRecognizer(tap)
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        textView.accessibilityLabel = placeholder

        let wanted = RichTextFormatting.segments(of: text)
        let typeSize = context.environment.dynamicTypeSize
        let sizeChanged = coordinator.lastTypeSize != typeSize
        if (wanted != coordinator.lastSegments || sizeChanged) && textView.markedTextRange == nil {
            let selection = textView.selectedRange
            coordinator.isApplying = true
            textView.attributedText = HighlightBridge.nsAttributedString(from: text)
            let length = textView.attributedText.length
            let location = min(selection.location, length)
            textView.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
            coordinator.isApplying = false
            coordinator.emptyBlock = nil
            coordinator.lastSegments = wanted
            coordinator.syncTypingAttributes(textView)
            coordinator.updateToolbar(textView)
        }
        coordinator.lastTypeSize = typeSize

        if let request = reveal, request.token != coordinator.lastRevealToken {
            coordinator.lastRevealToken = request.token
            coordinator.reveal(request.id, in: textView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.bounds.width
        guard width > 0, width.isFinite else { return nil }
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, minHeight))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: HighlightTextView
        weak var textView: UITextView?
        var lastSegments: [RichSegment] = []
        var lastTypeSize: DynamicTypeSize?
        var lastRevealToken: UUID?
        /// True while the text view is being rewritten by code, so selection callbacks are ignored.
        var isApplying = false
        /// A heading or quote switched on for an empty line. There is no character to carry it yet, so the
        /// coordinator remembers it (and where the caret was) and puts it in the typing attributes.
        var emptyBlock: (location: Int, style: BlockStyle)?
        private var toolbar: FormattingToolbar?

        init(_ parent: HighlightTextView) {
            self.parent = parent
        }

        // MARK: Keyboard accessory

        func makeAccessory() -> FormattingToolbar {
            let bar = FormattingToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: FormattingToolbar.barHeight))
            bar.onAction = { [weak self] action in
                self?.perform(action)
            }
            bar.onDone = { [weak self] in
                self?.textView?.resignFirstResponder()
            }
            toolbar = bar
            return bar
        }

        func perform(_ action: FormattingToolbar.Action) {
            switch action {
            case .bold: toggleInline(.bold)
            case .italic: toggleInline(.italic)
            case .underline: toggleInline(.underline)
            case .heading: toggleBlock(.heading)
            case .bullet: toggleBlock(.bullet)
            case .numbered: toggleBlock(.numbered)
            case .quote: toggleBlock(.quote)
            case .highlight: highlightSelection()
            }
        }

        /// Which toolbar toggles are on for the current selection (or typing position).
        private func activeActions(in textView: UITextView) -> Set<FormattingToolbar.Action> {
            let selection = textView.selectedRange
            let content = textView.attributedText ?? NSAttributedString()
            var active: Set<FormattingToolbar.Action> = []

            let typing = RichFormat(attributes: textView.typingAttributes)
            let inline: [(InlineStyle, FormattingToolbar.Action)] = [
                (.bold, .bold), (.italic, .italic), (.underline, .underline)
            ]
            for (style, action) in inline {
                let on = selection.length > 0
                    ? RichTextOps.inlineState(style, in: content, range: selection)
                    : typing.has(style)
                if on { active.insert(action) }
            }

            let blocks: [(BlockStyle, FormattingToolbar.Action)] = [
                (.heading, .heading), (.bullet, .bullet), (.numbered, .numbered), (.quote, .quote)
            ]
            let caret = caretBlock(in: textView)
            for (style, action) in blocks {
                let on = selection.length > 0
                    ? RichTextOps.blockState(style, in: content, selection: selection)
                    : caret == style
                if on { active.insert(action) }
            }
            return active
        }

        /// The block style at the caret (from the paragraph, or from `emptyBlock` on an empty line).
        private func caretBlock(in textView: UITextView) -> BlockStyle? {
            let selection = textView.selectedRange
            let content = textView.attributedText ?? NSAttributedString()
            let string = NSString(string: content.string)
            guard let paragraph = RichTextOps.paragraphs(
                in: string,
                covering: NSRange(location: selection.location, length: 0)
            ).first else { return nil }
            if paragraph.length == 0 {
                return emptyBlock?.location == selection.location ? emptyBlock?.style : nil
            }
            return RichTextOps.block(ofParagraph: paragraph, in: content)
        }

        func updateToolbar(_ textView: UITextView) {
            toolbar?.update(
                active: activeActions(in: textView),
                highlightEnabled: highlightableRange(in: textView) != nil
            )
        }

        // MARK: Typing attributes

        /// Keeps the typing attributes right for the caret: no highlight is carried along, and the block style is the
        /// one of the paragraph the caret is in (an empty line only has `emptyBlock`).
        func syncTypingAttributes(_ textView: UITextView) {
            var format = RichFormat(attributes: textView.typingAttributes)
            format.highlightID = nil
            let selection = textView.selectedRange
            if selection.length == 0 {
                format.block = caretBlock(in: textView)
            }
            textView.typingAttributes = HighlightBridge.styledAttributes(for: format)
        }

        // MARK: Formatting

        private func toggleInline(_ style: InlineStyle) {
            guard let textView else { return }
            let selection = textView.selectedRange
            if selection.length == 0 {
                // Nothing selected: the style applies to what is typed next.
                var format = RichFormat(attributes: textView.typingAttributes)
                format.highlightID = nil
                format.set(style, !format.has(style))
                textView.typingAttributes = HighlightBridge.styledAttributes(for: format)
                updateToolbar(textView)
                return
            }
            let model = NSMutableAttributedString(attributedString: textView.attributedText)
            RichTextOps.toggleInline(style, in: model, range: selection)
            apply(model, selection: selection)
        }

        private func toggleBlock(_ style: BlockStyle) {
            guard let textView else { return }
            let selection = textView.selectedRange
            let model = NSMutableAttributedString(attributedString: textView.attributedText)

            // A heading or quote on an empty line has no character to carry it: remember it for the next typing.
            if selection.length == 0, !style.isList {
                let string = NSString(string: model.string)
                if let paragraph = RichTextOps.paragraphs(in: string, covering: selection).first, paragraph.length == 0 {
                    if emptyBlock?.location == selection.location, emptyBlock?.style == style {
                        emptyBlock = nil
                    } else {
                        emptyBlock = (location: selection.location, style: style)
                    }
                    syncTypingAttributes(textView)
                    updateToolbar(textView)
                    return
                }
            }

            var wanted = selection
            RichTextOps.toggleBlock(style, in: model, selection: &wanted)
            apply(model, selection: wanted)
        }

        /// Writes `model` into the text view (with fonts), restores the selection, saves to the binding and
        /// refreshes the toolbar. The undo stack is cleared because code edits would leave it pointing at old ranges.
        private func apply(_ model: NSMutableAttributedString, selection: NSRange) {
            guard let textView else { return }
            var wanted = selection
            RichTextOps.normalize(model, selection: &wanted)
            isApplying = true
            textView.attributedText = HighlightBridge.styled(model)
            let length = textView.attributedText.length
            let location = min(wanted.location, length)
            textView.selectedRange = NSRange(location: location, length: min(wanted.length, length - location))
            isApplying = false
            emptyBlock = nil
            syncTypingAttributes(textView)
            textView.undoManager?.removeAllActions()
            let new = commit(textView)
            parent.onEdit(new)
            updateToolbar(textView)
            Task { @MainActor in
                self.keepCaretVisible(textView)
            }
        }

        // MARK: Return and backspace in lists, quotes and headings

        /// Return in a list starts the next item (an empty item ends the list), in a heading starts a plain line,
        /// in a quote continues the quote (an empty quote line ends it). Returns true when handled here.
        private func handleReturn(in textView: UITextView, at caret: Int) -> Bool {
            let content = textView.attributedText ?? NSAttributedString()
            let string = NSString(string: content.string)
            guard let paragraph = RichTextOps.paragraphs(
                in: string,
                covering: NSRange(location: caret, length: 0)
            ).first else { return false }

            let found: BlockStyle?
            if paragraph.length == 0 {
                found = emptyBlock?.location == caret ? emptyBlock?.style : nil
            } else {
                found = RichTextOps.block(ofParagraph: paragraph, in: content)
            }
            guard let style = found else { return false }

            let prefix = style.isList ? RichTextOps.prefixLength(of: style, in: string, paragraph: paragraph) : 0
            let contentStart = paragraph.location + prefix
            let contentEnd = RichTextOps.contentEnd(of: paragraph, in: string)
            let model = NSMutableAttributedString(attributedString: content)
            var selection = NSRange(location: caret, length: 0)

            if contentEnd <= contentStart {
                if paragraph.length == 0 {
                    emptyBlock = nil
                    syncTypingAttributes(textView)
                    updateToolbar(textView)
                } else {
                    RichTextOps.toggleBlock(style, in: model, selection: &selection)
                    apply(model, selection: selection)
                }
                return true
            }

            switch style {
            case .bullet, .numbered:
                let at = max(caret, contentStart)
                let insertion = NSAttributedString(
                    string: "\n" + RichTextOps.listPrefix(for: style, number: 1),
                    attributes: [.selahBlock: style.rawValue]
                )
                model.insert(insertion, at: at)
                apply(model, selection: NSRange(location: at + insertion.length, length: 0))
                return true
            case .heading:
                guard caret >= contentEnd else { return false }
                let hasTrailingNewline = contentEnd < paragraph.location + paragraph.length
                model.insert(NSAttributedString(string: "\n", attributes: [.selahBlock: style.rawValue]), at: caret)
                if hasTrailingNewline {
                    model.removeAttribute(.selahBlock, range: NSRange(location: caret + 1, length: 1))
                }
                apply(model, selection: NSRange(location: caret + 1, length: 0))
                return true
            case .quote:
                return false
            }
        }

        /// Backspace right after a list marker removes the marker and the list style (the item becomes a plain line).
        private func handleBackspace(in textView: UITextView, range: NSRange) -> Bool {
            let content = textView.attributedText ?? NSAttributedString()
            let string = NSString(string: content.string)
            let caret = range.location + range.length
            guard let paragraph = RichTextOps.paragraphs(
                in: string,
                covering: NSRange(location: caret, length: 0)
            ).first,
                let style = RichTextOps.block(ofParagraph: paragraph, in: content),
                style.isList else { return false }
            let prefix = RichTextOps.prefixLength(of: style, in: string, paragraph: paragraph)
            guard prefix > 0, caret == paragraph.location + prefix else { return false }
            let model = NSMutableAttributedString(attributedString: content)
            var selection = NSRange(location: caret, length: 0)
            RichTextOps.toggleBlock(style, in: model, selection: &selection)
            apply(model, selection: selection)
            return true
        }

        // MARK: Highlighting

        /// The selected words without surrounding spaces, or nil when nothing can be highlighted
        /// (no selection, only spaces, or the selection already touches a highlight).
        private func highlightableRange(in textView: UITextView) -> NSRange? {
            let selection = textView.selectedRange
            guard selection.length > 0 else { return nil }
            let string = (textView.text ?? "") as NSString
            guard selection.location + selection.length <= string.length else { return nil }
            let selected = string.substring(with: selection)
            let leading = selected.prefix(while: { $0.isWhitespace }).utf16.count
            let trimmed = selected.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let range = NSRange(location: selection.location + leading, length: trimmed.utf16.count)

            var touchesHighlight = false
            textView.attributedText.enumerateAttribute(.selahHighlightID, in: range, options: []) { value, _, stop in
                if value != nil {
                    touchesHighlight = true
                    stop.pointee = true
                }
            }
            return touchesHighlight ? nil : range
        }

        func highlightSelection() {
            guard let textView, let range = highlightableRange(in: textView) else { return }
            let model = NSMutableAttributedString(attributedString: textView.attributedText)
            // Only the user's words: list markers and line breaks inside the selection are left out.
            let pieces = RichTextOps.contentRanges(in: model, covering: range)
            guard !pieces.isEmpty else { return }
            let string = NSString(string: model.string)
            let quote = pieces.map { string.substring(with: $0) }.joined(separator: " ")
            let id = HighlightLogic.newID()
            for piece in pieces {
                model.addAttribute(.selahHighlightID, value: id, range: piece)
            }
            apply(model, selection: NSRange(location: range.location + range.length, length: 0))
            parent.onHighlight(id, quote)
        }

        /// Copies the text view's content into the binding.
        private func commit(_ textView: UITextView) -> AttributedString {
            let segments = RichTextBridge.segments(from: textView.attributedText)
            lastSegments = segments
            let new = RichTextFormatting.attributedString(from: segments)
            parent.text = new
            return new
        }

        // MARK: Reveal and scrolling

        func reveal(_ id: String, in textView: UITextView) {
            var found: NSRange?
            textView.attributedText.enumerateAttribute(
                .selahHighlightID,
                in: NSRange(location: 0, length: textView.attributedText.length),
                options: []
            ) { value, range, stop in
                if let value = value as? String, value == id {
                    found = range
                    stop.pointee = true
                }
            }
            guard let range = found else { return }
            textView.becomeFirstResponder()
            textView.selectedRange = range
            if let selected = textView.selectedTextRange {
                scrollOuter(to: textView.firstRect(for: selected), from: textView, padding: 80)
            }
        }

        /// The text view does not scroll itself, so scroll the screen's scroll view instead.
        private func scrollOuter(to rect: CGRect, from view: UIView, padding: CGFloat) {
            var ancestor = view.superview
            while let current = ancestor {
                if let scroll = current as? UIScrollView {
                    let target = view.convert(rect, to: scroll).insetBy(dx: 0, dy: -padding)
                    scroll.scrollRectToVisible(target, animated: true)
                    return
                }
                ancestor = current.superview
            }
        }

        private func keepCaretVisible(_ textView: UITextView) {
            guard textView.isFirstResponder, let end = textView.selectedTextRange?.end else { return }
            scrollOuter(to: textView.caretRect(for: end), from: textView, padding: 32)
        }

        // MARK: Tapping highlights

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard gesture.state == .ended, let textView else { return }
            let point = gesture.location(in: textView)
            guard let position = textView.closestPosition(to: point) else { return }
            let caret = textView.caretRect(for: position)
            guard point.y >= caret.minY - 4, point.y <= caret.maxY + 4 else { return }
            let index = textView.offset(from: textView.beginningOfDocument, to: position)
            let content = textView.attributedText ?? NSAttributedString()
            for candidate in [index, index - 1] where candidate >= 0 && candidate < content.length {
                if let id = content.attribute(.selahHighlightID, at: candidate, effectiveRange: nil) as? String {
                    parent.onHighlightTap(id)
                    return
                }
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: UITextViewDelegate

        func textViewDidChange(_ textView: UITextView) {
            emptyBlock = nil
            if textView.markedTextRange == nil {
                // Fix list numbers and prefixes after edits (deleted items, pasted text).
                let model = NSMutableAttributedString(attributedString: textView.attributedText)
                var selection = textView.selectedRange
                if RichTextOps.normalize(model, selection: &selection) {
                    apply(model, selection: selection)
                    return
                }
            }
            let new = commit(textView)
            parent.onEdit(new)
            updateToolbar(textView)
            Task { @MainActor in
                self.keepCaretVisible(textView)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !isApplying else { return }
            // Typing next to a highlight must not extend it; the block style follows the caret.
            syncTypingAttributes(textView)
            updateToolbar(textView)
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            var typing = textView.typingAttributes
            typing[.selahHighlightID] = nil
            typing[.backgroundColor] = nil
            textView.typingAttributes = typing

            guard textView.markedTextRange == nil else { return true }
            if text == "\n", range.length == 0, handleReturn(in: textView, at: range.location) {
                return false
            }
            if text.isEmpty, range.length == 1, handleBackspace(in: textView, range: range) {
                return false
            }
            return true
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard range.length > 0 else {
                return UIMenu(children: suggestedActions)
            }
            let active = activeActions(in: textView)
            var extra: [UIMenuElement] = []
            if highlightableRange(in: textView) != nil {
                extra.append(menuAction(.highlight, isOn: false))
            }
            let formatActions: [FormattingToolbar.Action] = [
                .bold, .italic, .underline, .heading, .bullet, .numbered, .quote
            ]
            let format = UIMenu(
                title: "Format",
                image: UIImage(named: PIcon.textB.assetName()),
                children: formatActions.map { menuAction($0, isOn: active.contains($0)) }
            )
            return UIMenu(children: extra + [format] + suggestedActions)
        }

        private func menuAction(_ action: FormattingToolbar.Action, isOn: Bool) -> UIAction {
            UIAction(
                title: action.label,
                image: UIImage(named: action.icon.assetName()),
                state: isOn ? .on : .off
            ) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.perform(action)
                }
            }
        }
    }
}
