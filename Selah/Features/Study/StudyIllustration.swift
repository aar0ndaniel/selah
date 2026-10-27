import SwiftUI
import UIKit

/// Built-in pictures for study cards, drawn by the Selah art agent in the mascot's style (asset names
/// `Study-<raw value>`). Only the ones already in the asset catalog are offered.
enum StudyIllustration: String, CaseIterable, Identifiable, Sendable {
    case reading
    case prayer
    case lamp
    case star
    case sunrise
    case path

    var id: String { rawValue }

    var assetName: String { "Study-\(rawValue)" }

    /// Plain name for VoiceOver and the picker.
    var title: String {
        switch self {
        case .reading: return "Reading"
        case .prayer: return "Prayer"
        case .lamp: return "Lamp"
        case .star: return "Star"
        case .sunrise: return "Sunrise"
        case .path: return "Path"
        }
    }

    var image: UIImage? { UIImage(named: assetName) }

    /// The illustrations that are in the catalog.
    static var available: [StudyIllustration] { allCases.filter { $0.image != nil } }
}

extension ReadingPlan {
    /// The chosen built-in illustration, if any.
    var illustration: StudyIllustration? {
        get { StudyIllustration(rawValue: illustrationRaw) }
        set { illustrationRaw = newValue?.rawValue ?? "" }
    }
}

/// The picture on a study card: the banner photo, else the chosen illustration, else Selah reading on the card colour.
struct StudyArtwork: View {
    let plan: ReadingPlan

    var body: some View {
        if let data = plan.bannerData, let photo = UIImage(data: data) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
        } else if let art = plan.illustration?.image {
            Image(uiImage: art)
                .resizable()
                .scaledToFill()
        } else {
            ZStack(alignment: .bottomTrailing) {
                Theme.card
                MascotView(activity: .reading, animated: false)
                    .frame(width: 112, height: 112)
                    .padding(Theme.Spacing.s)
            }
        }
    }

    /// True when a photo or illustration fills the card, so text needs a scrim.
    static func hasPicture(_ plan: ReadingPlan) -> Bool {
        plan.bannerData != nil || plan.illustration?.image != nil
    }
}
