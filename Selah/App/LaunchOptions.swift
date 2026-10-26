import SwiftUI
import SwiftData

/// Launch arguments used by the screenshot UI tests (SelahUITests). A normal launch has none of them.
///
/// - `-uiTestSampleData`: in-memory store seeded with `SampleData`, onboarding already done.
/// - `-uiTestOnboarding`: empty in-memory store, so the first-launch onboarding shows.
/// - `-uiTestDark`: forces dark mode (wins over the profile's appearance setting).
/// - `-uiTestMood`: lets the daily mood check-in appear in a test launch (it is skipped otherwise, so it never
///   covers the other screenshots).
struct LaunchOptions: Sendable {
    let sampleData: Bool
    let onboarding: Bool
    let dark: Bool
    let moodCheckIn: Bool

    static let sampleDataArgument = "-uiTestSampleData"
    static let onboardingArgument = "-uiTestOnboarding"
    static let darkArgument = "-uiTestDark"
    static let moodArgument = "-uiTestMood"

    init(arguments: [String]) {
        sampleData = arguments.contains(Self.sampleDataArgument)
        onboarding = arguments.contains(Self.onboardingArgument)
        dark = arguments.contains(Self.darkArgument)
        moodCheckIn = arguments.contains(Self.moodArgument)
    }

    static var current: LaunchOptions { LaunchOptions(arguments: ProcessInfo.processInfo.arguments) }

    /// True when the app should use a throwaway in-memory store instead of the real one.
    var usesTestStore: Bool { sampleData || onboarding }

    /// The daily mood check-in may show: always in a normal launch, in a test launch only with `-uiTestMood`.
    var allowsMoodCheckIn: Bool { !usesTestStore || moodCheckIn }

    /// Colour scheme forced by a launch argument, or nil to follow the profile / system.
    var forcedScheme: ColorScheme? { dark ? .dark : nil }

    /// The in-memory container for a test launch, or nil for a normal launch.
    /// Onboarding wins over sample data when both are passed.
    @MainActor
    func makeTestContainer() -> ModelContainer? {
        guard usesTestStore else { return nil }
        return SampleData.makeContainer(seeded: sampleData && !onboarding)
    }
}
