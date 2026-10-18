import Foundation
import SwiftData

@Model
final class UserProfile {
    var name: String = ""
    @Attribute(.externalStorage) var photoData: Data?
    var congregation: String = ""
    var translation: Translation = Translation.kjv
    /// Verse text size in points.
    var textSize: Double = 17
    var appearance: Appearance = Appearance.system
    var onboarded: Bool = false

    init(
        name: String = "",
        photoData: Data? = nil,
        congregation: String = "",
        translation: Translation = .kjv,
        textSize: Double = 17,
        appearance: Appearance = .system,
        onboarded: Bool = false
    ) {
        self.name = name
        self.photoData = photoData
        self.congregation = congregation
        self.translation = translation
        self.textSize = textSize
        self.appearance = appearance
        self.onboarded = onboarded
    }
}
