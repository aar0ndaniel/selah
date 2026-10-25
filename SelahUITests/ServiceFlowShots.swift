import XCTest

/// Walks through recording a service (add a sermon, a verse, a Bible class, a hymn) and screenshots each step,
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

        // 2. Open today's service (meeting-day card), or start one with the + button. A new service is empty:
        //    just the Add sermon / Add Bible class / Add song buttons.
        let open = first([
            app.buttons["Add notes for today's service"],
            app.buttons["Open today's service"],
            app.buttons["New service for today"],
            app.buttons["plus-button"]
        ])
        tap(open)
        pause(2)
        snap(app, "s\(prefix)2-service-page-\(mode)")

        // 3. Add a sermon and fill it in (the new part opens and its title gets focus).
        tap(first([app.buttons["add-part-sermon"], app.buttons["Add sermon"]]))
        pause(1.5)
        type(into: lastField(app, prefix: "field-part-title-"), "Grace that keeps")
        type(into: lastField(app, prefix: "field-part-person-"), "Pastor Mensah\n")
        dismissKeyboard(app)
        snap(app, "s\(prefix)3-sermon-filled-\(mode)")

        // 4. Add a verse to the sermon.
        tap(lastMatch(app.buttons, prefix: "add-verse-") ?? first([app.buttons["Add verse"]]))
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

        // 5. Add a Bible class below the sermon and fill it in.
        scrollTo(app, app.buttons["add-part-class"])
        tap(first([app.buttons["add-part-class"], app.buttons["Add Bible class"]]))
        pause(1.5)
        type(into: lastField(app, prefix: "field-part-title-"), "Walking in the Spirit")
        type(into: lastField(app, prefix: "field-part-person-"), "Deacon Owusu\n")
        dismissKeyboard(app)
        snap(app, "s\(prefix)6-bible-class-\(mode)")

        // 6. Add a song: a hymn with its number and title.
        scrollTo(app, app.buttons["add-part-song"])
        tap(first([app.buttons["add-part-song"], app.buttons["Add song"]]))
        pause(1.5)
        tap(first([app.segmentedControls.buttons["Hymn"], app.buttons["Hymn"]], timeout: 2))
        // The app focuses the new song's hymn number field; type into it (tapping first is harmless).
        type(into: lastField(app, prefix: "field-hymn-number-"), "212")
        dismissKeyboard(app)
        type(into: lastField(app, prefix: "field-part-title-"), "Great is thy faithfulness\n")
        dismissKeyboard(app)
        snap(app, "s\(prefix)7-songs-\(mode)")
    }

    // MARK: - Helpers

    /// The last element (newest part) whose identifier starts with `prefix`.
    @MainActor
    private func lastMatch(_ query: XCUIElementQuery, prefix: String) -> XCUIElement? {
        let matches = query.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        guard matches.firstMatch.waitForExistence(timeout: 3) else { return nil }
        let count = matches.count
        return count > 0 ? matches.element(boundBy: count - 1) : nil
    }

    /// A text field or multi-line text view of the newest part.
    @MainActor
    private func lastField(_ app: XCUIApplication, prefix: String) -> XCUIElement? {
        lastMatch(app.textFields, prefix: prefix) ?? lastMatch(app.textViews, prefix: prefix)
    }

    /// Swipes up a few times until `element` is on screen.
    @MainActor
    private func scrollTo(_ app: XCUIApplication, _ element: XCUIElement) {
        var tries = 0
        while tries < 4 && !(element.exists && element.isHittable) {
            app.swipeUp()
            pause(0.6)
            tries += 1
        }
    }

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
