import XCTest

/// Captures the main screens as XCTAttachments so CI can show what the app looks like without a Mac.
/// Run by the `[shots]` step of .github/workflows/ios-build.yml, never by the unit-test step.
///
/// Launch arguments (see Selah/App/LaunchOptions.swift):
///   -uiTestSampleData   in-memory store with sample content, onboarding done
///   -uiTestOnboarding   empty in-memory store, shows first-launch onboarding
///   -uiTestDark         forces dark mode
///   -uiTestMood         lets the daily mood check-in appear (otherwise it is skipped in test launches)
///
/// Each screen is its own test (its own launch) so one broken screen does not hide the others.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Light

    @MainActor
    func test01TodayLight() {
        let app = launchApp()
        settle()
        snap(app, "01-today-light")
    }

    @MainActor
    func test02StudyLight() {
        let app = launchApp()
        openTab(app, .study)
        snap(app, "02-study-light")
    }

    @MainActor
    func test03BookLight() {
        let app = launchApp()
        openTab(app, .study)
        let card = app.descendants(matching: .any).matching(identifier: "book-card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 10), "No book card on the Study tab")
        card.tap()
        settle(2)
        snap(app, "03-book-light")
    }

    @MainActor
    func test04ServicesLight() {
        let app = launchApp()
        openTab(app, .services)
        snap(app, "04-services-light")
    }

    @MainActor
    func test05NotesLight() {
        let app = launchApp()
        openTab(app, .notes)
        snap(app, "05-notes-light")
    }

    @MainActor
    func test06SettingsLight() {
        let app = launchApp()
        let profile = firstExisting([
            app.buttons["profile-button"],
            app.buttons["Profile and settings"]
        ])
        XCTAssertNotNil(profile, "Profile button not found on Today")
        profile?.tap()
        settle(2)
        snap(app, "06-settings-light")
    }

    @MainActor
    func test07OnboardingLight() {
        let app = launchApp(sampleData: false, extra: [Self.onboardingArgument])
        // The three story pages, then the first setup page.
        _ = app.staticTexts["Sing every hymn by heart"].waitForExistence(timeout: 10)
        settle()
        snap(app, "07-onboarding-light")
        let next = app.buttons["intro-continue"]
        for name in ["07b-onboarding-services", "07c-onboarding-study"] where next.waitForExistence(timeout: 5) {
            next.tap()
            settle()
            snap(app, name)
        }
        if next.waitForExistence(timeout: 5) {
            next.tap()
            _ = app.staticTexts["Welcome to Tehila"].waitForExistence(timeout: 10)
            settle()
            snap(app, "07d-onboarding-welcome")
        }
    }

    // MARK: - Dark

    @MainActor
    func test08TodayDark() {
        let app = launchApp(extra: [Self.darkArgument])
        settle()
        snap(app, "08-today-dark")
    }

    @MainActor
    func test09NotesDark() {
        let app = launchApp(extra: [Self.darkArgument])
        openTab(app, .notes)
        snap(app, "09-notes-dark")
    }

    @MainActor
    func test10SongsLight() {
        let app = launchApp()
        openTab(app, .songs)
        snap(app, "10-songs-light")
    }

    /// The daily mood check-in. `-uiTestMood` lets it appear (the sample data has no entry for today).
    @MainActor
    func test11MoodLight() {
        let app = launchApp(extra: ["-uiTestMood"])
        let title = app.descendants(matching: .any).matching(identifier: "mood-title").firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The mood check-in did not appear")
        settle()
        snap(app, "11-mood-light")
    }

    /// Opens the first song that has lyrics, then its practice view.
    @MainActor
    func test13SongLyricsLight() {
        let app = launchApp()
        openTab(app, .songs)
        let row = app.descendants(matching: .any).matching(identifier: "song-row-lyrics").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No song with lyrics on the Songs tab")
        row.tap()
        settle(2)
        let practise = app.descendants(matching: .any).matching(identifier: "song-practise").firstMatch
        XCTAssertTrue(practise.waitForExistence(timeout: 10), "No Practise button on the song page")
        practise.tap()
        settle(2)
        snap(app, "13-song-lyrics-light")
    }

    // MARK: - Helpers

    private static let sampleDataArgument = "-uiTestSampleData"
    private static let onboardingArgument = "-uiTestOnboarding"
    private static let darkArgument = "-uiTestDark"

    private enum Tab {
        case today, study, services, notes, songs

        var title: String {
            switch self {
            case .today: return "Today"
            case .study: return "Study"
            case .services: return "Services"
            case .notes: return "Notes"
            case .songs: return "Songs"
            }
        }

        var identifier: String {
            switch self {
            case .today: return "tab-today"
            case .study: return "tab-study"
            case .services: return "tab-services"
            case .notes: return "tab-notes"
            case .songs: return "tab-songs"
            }
        }
    }

    @MainActor
    private func launchApp(sampleData: Bool = true, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (sampleData ? [Self.sampleDataArgument] : []) + extra
        app.launch()
        return app
    }

    /// Lets animations and lazy content finish before a screenshot.
    @MainActor
    private func settle(_ seconds: TimeInterval = 1.5) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    private func firstExisting(_ elements: [XCUIElement], timeout: TimeInterval = 5) -> XCUIElement? {
        for element in elements where element.waitForExistence(timeout: timeout) {
            return element
        }
        return nil
    }

    @MainActor
    private func openTab(_ app: XCUIApplication, _ tab: Tab) {
        let button = firstExisting([
            app.tabBars.buttons[tab.title],
            app.buttons[tab.identifier],
            app.buttons[tab.title]
        ])
        XCTAssertNotNil(button, "Tab \(tab.title) not found")
        button?.tap()
        settle()
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
