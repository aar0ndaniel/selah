import Foundation
import SwiftUI

/// Marks a highlighted run of text. The value matches `NoteComment.highlightID`.
enum HighlightIDAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "selah.highlightID"
}

extension AttributeScopes {
    struct SelahAttributes: AttributeScope {
        let highlightID: HighlightIDAttribute
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
