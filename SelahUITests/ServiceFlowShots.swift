import XCTest

/// Walks through recording a service (sermon, verse, Bible class, songs) and screenshots each step,
/// so the owner can see the flow without a Mac. Runs only in the `[shots]` CI step.
/// Steps are best-effort: if an element can't be found the walk carries on and still screenshots.
final class ServiceFlowShots: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    @MainActor
    func test11ServiceFlowLight() {
        walkServiceFlow(dark: false, prefix: "1")
    }

    @MainActor
    func test12ServiceFlowDark() {
        walkServiceFlow(dark: true, prefix: "2")
    }

    // MARK: - Flow

    @MainActor
    private func walkServiceFlow(dark: Bool, prefix: String) {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestSampleData"] + (dark ? ["-uiTestDark"] : [])
        app.launch()
        let mode = dark ? "dark" : "light"

        // 1. Services tab.
        tap(first([app.tabBars.buttons["Services"], app.buttons["tab-services"], app.buttons["Services"]]))
        pause()
        snap(app, "s\(prefix)1-services-\(mode)")

        // 2. Open today's service (meeting-day card), or start one with the + button.
        let open = first([
            app.buttons["Add notes for today's service"],
            app.buttons["Open today's service"],
            app.buttons["New service for today"],
            app.buttons["plus-button"]
        ])
        tap(open)
        pause(2)
        snap(app, "s\(prefix)2-service-page-\(mode)")

        // 3. Fill in the sermon.
        type(into: first([app.textFields["field-sermon-title"], app.textViews["field-sermon-title"],
                          app.textFields["Title"], app.textViews["Title"]]), "Grace that keeps")
        type(into: first([app.textFields["field-sermonist"], app.textFields["Sermonist"]]), "Pastor Mensah\n")
        dismissKeyboard(app)
        snap(app, "s\(prefix)3-sermon-filled-\(mode)")

        // 4. Add a verse to the sermon.
        tap(first([app.buttons["Add verse"]]))
        pause(1.5)
        if let search = first([app.searchFields.firstMatch, app.textFields["John 3:16 or Psalm 23"]], timeout: 4),
           search.exists, search.isHittable {
            search.tap()
            search.typeText("Rom 8:28")
            pause(1.5)
        }
        snap(app, "s\(prefix)4-verse-picker-\(mode)")
        tap(first([app.buttons.containing(NSPredicate(format: "label CONTAINS[c] 'Romans 8:28'")).firstMatch,
                   app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] 'all things work together'")).firstMatch],
                  timeout: 4))
        pause(1.5)
        snap(app, "s\(prefix)5-verse-added-\(mode)")

        // 5. Open the Bible class section and fill it in.
        app.swipeUp()
        pause()
        // A new service opens Bible class already; only tap the header if the fields are not showing.
        let lessonField = first([app.textFields["field-class-lesson"], app.textViews["field-class-lesson"]], timeout: 1)
        if lessonField == nil {
            tap(first([app.buttons["section-class"], app.staticTexts["section-class"],
                       app.buttons["Bible class"], app.staticTexts["Bible class"]]))
            pause()
        }
        type(into: first([app.textFields["field-class-lesson"], app.textViews["field-class-lesson"],
                          app.textFields["Lesson"], app.textViews["Lesson"]]), "Walking in the Spirit")
        type(into: first([app.textFields["field-class-teacher"], app.textFields["Taught by"]]), "Deacon Owusu\n")
        dismissKeyboard(app)
        snap(app, "s\(prefix)6-bible-class-\(mode)")

        // 6. Songs.
        app.swipeUp()
        pause()
        tap(first([app.buttons["add-song"], app.buttons["Add song"]]))
        pause(1.5)
        // The app focuses the new song's hymn number field; type into it (tapping first is harmless).
        type(into: first([app.textFields["field-hymn-number"], app.textFields["Hymn number"]]), "212")
        dismissKeyboard(app)
        type(into: first([app.textFields["field-song-title"], app.textFields["Song title"]]), "Great is thy faithfulness\n")
        dismissKeyboard(app)
        snap(app, "s\(prefix)7-songs-\(mode)")
    }

    // MARK: - Helpers

    @MainActor
    private func first(_ elements: [XCUIElement], timeout: TimeInterval = 3) -> XCUIElement? {
        for element in elements where element.waitForExistence(timeout: timeout) {
            return element
        }
        return nil
    }

    @MainActor
    private func tap(_ element: XCUIElement?) {
        guard let element, element.exists, element.isHittable else { return }
        element.tap()
    }

    @MainActor
    private func type(into element: XCUIElement?, _ text: String) {
        guard let element, element.exists, element.isHittable else { return }
        element.tap()
        element.typeText(text)
    }

    @MainActor
    private func dismissKeyboard(_ app: XCUIApplication) {
        if app.keyboards.firstMatch.exists {
            if app.buttons["keyboard-done"].exists && app.buttons["keyboard-done"].isHittable {
                app.buttons["keyboard-done"].tap()
            } else if app.toolbars.buttons["Done"].exists {
                app.toolbars.buttons["Done"].tap()
            } else if app.buttons["format-done"].exists {
                app.buttons["format-done"].tap()
            } else {
                app.swipeDown()
            }
        }
        pause(0.8)
    }

    @MainActor
    private func pause(_ seconds: TimeInterval = 1.2) {
        Thread.sleep(forTimeInterval: seconds)
    }

    @MainActor
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
