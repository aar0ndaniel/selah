import SwiftUI
import UIKit

extension NSAttributedString.Key {
    /// UIKit twin of `HighlightIDAttribute`. Only lives inside the text view; the model keeps `HighlightIDAttribute`.
    static var selahHighlightID: NSAttributedString.Key {
        NSAttributedString.Key("selah.highlightID")
    }
}

/// Converts between the stored `AttributedString` and the text view's `NSAttributedString`.
/// It copies words and highlight IDs only, by hand, so nothing depends on automatic attribute bridging.
@MainActor
enum HighlightBridge {
    static var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.preferredFont(forTextStyle: .body),
            .foregroundColor: UIColor.label
        ]
    }

    static var highlightColor: UIColor {
        UIColor(named: "HighlightMint") ?? .systemMint
    }

    static func nsAttributedString(from text: AttributedString) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for segment in HighlightLogic.segments(of: text) {
            var attributes = baseAttributes
            if let id = segment.highlightID {
                attributes[.selahHighlightID] = id
                attributes[.backgroundColor] = highlightColor
            }
            result.append(NSAttributedString(string: segment.string, attributes: attributes))
        }
        return result
    }

    static func segments(from text: NSAttributedString) -> [HighlightLogic.Segment] {
        var result: [HighlightLogic.Segment] = []
        let string = text.string as NSString
        text.enumerateAttribute(
            .selahHighlightID,
            in: NSRange(location: 0, length: text.length),
            options: []
        ) { value, range, _ in
            let piece = string.substring(with: range)
            let id = value as? String
            if let last = result.last, last.highlightID == id {
                result[result.count - 1].string += piece
            } else {
                result.append(HighlightLogic.Segment(string: piece, highlightID: id))
            }
        }
        return result
    }

    static func attributedString(from text: NSAttributedString) -> AttributedString {
        HighlightLogic.attributedString(from: segments(from: text))
    }
}

/// Asks the text view to select a highlight and bring it into view.
struct RevealRequest: Equatable {
    let id: String
    let token = UUID()
}

/// A self-sizing UITextView with highlight support. It is used because it gives exact control over
/// selection, typing attributes and tap detection (see RichNoteEditor).
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

        let wanted = HighlightLogic.segments(of: text)
        let typeSize = context.environment.dynamicTypeSize
        let sizeChanged = coordinator.lastTypeSize != typeSize
        if (wanted != coordinator.lastSegments || sizeChanged) && textView.markedTextRange == nil {
            let selection = textView.selectedRange
            textView.attributedText = HighlightBridge.nsAttributedString(from: text)
            let length = textView.attributedText.length
            let location = min(selection.location, length)
            textView.selectedRange = NSRange(location: location, length: min(selection.length, length - location))
            textView.typingAttributes = HighlightBridge.baseAttributes
            coordinator.lastSegments = wanted
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
        var lastSegments: [HighlightLogic.Segment] = []
        var lastTypeSize: DynamicTypeSize?
        var lastRevealToken: UUID?
        private var highlightItem: UIBarButtonItem?

        init(_ parent: HighlightTextView) {
            self.parent = parent
        }

        // MARK: Keyboard accessory

        func makeAccessory() -> UIToolbar {
            let bar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
            let highlight = UIBarButtonItem(
                title: "Highlight",
                style: .plain,
                target: self,
                action: #selector(highlightTapped)
            )
            highlight.isEnabled = false
            highlight.accessibilityLabel = "Highlight"
            highlight.accessibilityHint = "Highlights the selected words and lets you add a comment."
            highlightItem = highlight

            let done = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneTapped))
            done.accessibilityHint = "Closes the keyboard."
            bar.items = [highlight, UIBarButtonItem(systemItem: .flexibleSpace), done]
            bar.sizeToFit()
            return bar
        }

        @objc private func highlightTapped() {
            highlightSelection()
        }

        @objc private func doneTapped() {
            textView?.resignFirstResponder()
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
            let quote = ((textView.text ?? "") as NSString).substring(with: range)
            let id = HighlightLogic.newID()

            let mutable = NSMutableAttributedString(attributedString: textView.attributedText)
            mutable.addAttributes(
                [.selahHighlightID: id, .backgroundColor: HighlightBridge.highlightColor],
                range: range
            )
            textView.attributedText = mutable
            textView.selectedRange = NSRange(location: range.location + range.length, length: 0)
            textView.typingAttributes = HighlightBridge.baseAttributes
            _ = commit(textView)
            updateHighlightAvailability(textView)
            parent.onHighlight(id, quote)
        }

        private func updateHighlightAvailability(_ textView: UITextView) {
            highlightItem?.isEnabled = highlightableRange(in: textView) != nil
        }

        /// Copies the text view's content into the binding.
        private func commit(_ textView: UITextView) -> AttributedString {
            let segments = HighlightBridge.segments(from: textView.attributedText)
            lastSegments = segments
            let new = HighlightLogic.attributedString(from: segments)
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
            let new = commit(textView)
            parent.onEdit(new)
            Task { @MainActor in
                self.keepCaretVisible(textView)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateHighlightAvailability(textView)
            if textView.selectedRange.length == 0 {
                // Typing next to a highlight must not extend it.
                textView.typingAttributes = HighlightBridge.baseAttributes
            }
        }

        func textView(
            _ textView: UITextView,
            shouldChangeTextIn range: NSRange,
            replacementText text: String
        ) -> Bool {
            textView.typingAttributes = HighlightBridge.baseAttributes
            return true
        }

        func textView(
            _ textView: UITextView,
            editMenuForTextIn range: NSRange,
            suggestedActions: [UIMenuElement]
        ) -> UIMenu? {
            guard highlightableRange(in: textView) != nil else {
                return UIMenu(children: suggestedActions)
            }
            let action = UIAction(title: "Highlight", image: UIImage(systemName: "highlighter")) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.highlightSelection()
                }
            }
            return UIMenu(children: [action] + suggestedActions)
        }
    }
}
