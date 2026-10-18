import SwiftUI
import SwiftData

/// Launch arguments used by the screenshot UI tests (SelahUITests). A normal launch has none of them.
///
/// - `-uiTestSampleData`: in-memory store seeded with `SampleData`, onboarding already done.
/// - `-uiTestOnboarding`: empty in-memory store, so the first-launch onboarding shows.
/// - `-uiTestDark`: forces dark mode (wins over the profile's appearance setting).
struct LaunchOptions: Sendable {
    let sampleData: Bool
    let onboarding: Bool
    let dark: Bool

    static let sampleDataArgument = "-uiTestSampleData"
    static let onboardingArgument = "-uiTestOnboarding"
    static let darkArgument = "-uiTestDark"

    init(arguments: [String]) {
        sampleData = arguments.contains(Self.sampleDataArgument)
        onboarding = arguments.contains(Self.onboardingArgument)
        dark = arguments.contains(Self.darkArgument)
    }

    static var current: LaunchOptions { LaunchOptions(arguments: ProcessInfo.processInfo.arguments) }

    /// True when the app should use a throwaway in-memory store instead of the real one.
    var usesTestStore: Bool { sampleData || onboarding }

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
