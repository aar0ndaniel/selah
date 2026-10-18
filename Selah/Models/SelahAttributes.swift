import Foundation
import SwiftUI

/// Marks a highlighted run of text. The value matches `NoteComment.highlightID`.
enum HighlightIDAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "selah.highlightID"
}

/// Underline on a run of text. Foundation has no Codable underline key, so Selah stores its own.
/// Bold, italic and strikethrough use Foundation's `inlinePresentationIntent` (Codable in the Foundation scope).
enum SelahUnderlineAttribute: CodableAttributedStringKey {
    typealias Value = Bool
    static let name = "selah.underline"
}

/// Block style of a paragraph: "h" (heading), "ul" (bulleted list), "ol" (numbered list) or "quote".
/// Set on every run of the paragraph, including its trailing newline. List paragraphs also start with a real
/// text prefix (a bullet or "1. "), see `RichTextOps`. A custom key is used instead of Foundation's
/// `presentationIntent` because that one needs per-paragraph identities and does not merge or split safely.
enum BlockStyleAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "selah.block"
}

extension AttributeScopes {
    struct SelahAttributes: AttributeScope {
        let highlightID: HighlightIDAttribute
        let selahUnderline: SelahUnderlineAttribute
        let selahBlock: BlockStyleAttribute
        let foundation: AttributeScopes.FoundationAttributes
        let swiftUI: AttributeScopes.SwiftUIAttributes
    }

    var selah: SelahAttributes.Type { SelahAttributes.self }
}

extension AttributeDynamicLookup {
    subscript<T: AttributedStringKey>(
        dynamicMember keyPath: KeyPath<AttributeScopes.SelahAttributes, T>
    ) -> T {
        self[T.self]
    }
}

/// Encodes and decodes rich text so formatting and highlight IDs survive storage.
enum RichTextCoding {
    static func encode(_ text: AttributedString) -> Data {
        do {
            return try JSONEncoder().encode(text, configuration: AttributeScopes.SelahAttributes.self)
        } catch {
            return Data()
        }
    }

    static func decode(_ data: Data) -> AttributedString {
        guard !data.isEmpty else { return AttributedString() }
        do {
            return try JSONDecoder().decode(
                AttributedString.self,
                from: data,
                configuration: AttributeScopes.SelahAttributes.self
            )
        } catch {
            return AttributedString()
        }
    }
}
