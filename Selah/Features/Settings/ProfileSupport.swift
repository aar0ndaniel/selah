import SwiftUI
import SwiftData
import UserNotifications
import UIKit

// MARK: - Names and display helpers

extension Translation {
    var shortName: String { rawValue.uppercased() }

    var fullName: String {
        switch self {
        case .kjv: return "King James Version"
        case .asv: return "American Standard Version"
        case .web: return "World English Bible"
        case .bsb: return "Berean Standard Bible"
        }
    }
}

extension Appearance {
    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    /// nil follows the system setting.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// Verse text size choices, stored in `UserProfile.textSize` (points).
enum VerseTextSize: Double, CaseIterable, Sendable {
    case small = 15
    case standard = 17
    case large = 19
    case larger = 22
    case largest = 26

    var title: String {
        switch self {
        case .small: return "Small"
        case .standard: return "Standard"
        case .large: return "Large"
        case .larger: return "Larger"
        case .largest: return "Largest"
        }
    }

    /// The option closest to a stored value.
    static func nearest(to points: Double) -> VerseTextSize {
        allCases.min { abs($0.rawValue - points) < abs($1.rawValue - points) } ?? .standard
    }
}

// MARK: - Profile

enum ProfileStore {
    /// Returns the one UserProfile, creating it when none exists yet.
    @MainActor
    @discardableResult
    static func ensure(_ profiles: [UserProfile], in context: ModelContext) -> UserProfile {
        if let first = profiles.first { return first }
        let profile = UserProfile()
        context.insert(profile)
        return profile
    }

    /// Shrinks a picked photo so the profile stays small.
    static func avatarData(from data: Data, maxSide: CGFloat = 320) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

/// Round profile photo, or a person symbol when there is none.
struct AvatarView: View {
    let photoData: Data?
    var size: CGFloat = 32

    var body: some View {
        Group {
            if let photoData, let image = UIImage(data: photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: size * 0.9))
                    .foregroundStyle(.tint)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Notifications

/// Thin wrapper around the notification centre. Scheduling arrives in Phase 9.
enum NotificationAccess {
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Shows the system prompt. Call only after explaining why (rule 9.2).
    static func request() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func statusText(_ status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral: return "On"
        case .denied: return "Off in Settings"
        case .notDetermined: return "Not asked yet"
        @unknown default: return "Unknown"
        }
    }
}
