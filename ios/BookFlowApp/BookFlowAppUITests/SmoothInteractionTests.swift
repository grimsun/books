import XCTest

@MainActor
enum SeededHomeUITest {
    static func application(largeLibrary: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["BOOKFLOW_UI_TESTING"] = "1"
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "1"
        app.launchEnvironment["BOOKFLOW_LARGE_LIBRARY"] = largeLibrary ? "1" : "0"
        // NSArgumentDomain overrides the test suite's onboarding default without a setup launch.
        app.launchArguments = ["-session.onboarded", "YES"]
        return app
    }
}

@MainActor
final class SmoothInteractionTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSeededHomeStartsPromptlyWithoutNetworkRequests() throws {
        let app = SeededHomeUITest.application()
        defer { app.terminate() }
        let start = ProcessInfo.processInfo.systemUptime
        app.launch()
        let budget: TimeInterval = 5
        let today = app.buttons["reading-today"]
        XCTAssertTrue(today.waitForExistence(timeout: max(0, budget - elapsed(since: start))))
        XCTAssertTrue(today.isHittable, "The first Home frame must be interactive, not just a placeholder.")
        let rail = app.scrollViews["currently-reading-rail"]
        XCTAssertTrue(rail.exists, "Seeded currently-reading content must be populated at startup.")
        XCTAssertLessThanOrEqual(elapsed(since: start), budget, "Seeded Home exceeded its launch-to-content budget.")
        assertNoNetworkRequests(app)

        let home = app.scrollViews["home-scroll"]
        scrollTo(app.staticTexts["home-lists-anchor"], in: home, app: app, direction: .down)
        scrollTo(today, in: home, app: app, direction: .up)
        assertNoNetworkRequests(app)
    }

    func testTabSwitchingPreservesReadingShelfAndVisibleScrollAnchor() throws {
        let app = SeededHomeUITest.application(largeLibrary: true)
        defer { app.terminate() }
        app.launch()
        selectTab("Library", in: app)
        let shelf = app.buttons["library-shelf-reading"]
        XCTAssertTrue(shelf.waitForExistence(timeout: 3))
        shelf.tap()
        assertValue("Selected", of: shelf)
        let scroll = app.descendants(matching: .any)["library-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["library-book-stress-0"].waitForExistence(timeout: 3))
        for _ in 0..<4 { drag(scroll, direction: .down) }

        let anchor = try XCTUnwrap(scroll.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'library-book-stress-'")
        ).allElementsBoundByIndex.first { fullyVisible($0, in: scroll, app: app) })
        let identifier = anchor.identifier
        XCTAssertNotEqual(identifier, "library-book-stress-0", "The test must leave the top before switching tabs.")
        let index = try XCTUnwrap(Int(identifier.replacingOccurrences(of: "library-book-stress-", with: "")))
        XCTAssertTrue(index.isMultiple(of: 2), "The anchor must belong to the Reading shelf.")
        let frame = anchor.frame

        for destination in ["Home", "Search", "Profile"] {
            selectTab(destination, in: app)
            selectTab("Library", in: app)
            assertValue("reading", of: scroll)
            assertRestored(app.buttons[identifier], to: frame, in: scroll, app: app)
        }
    }

    func testHomeDownAndUpPreservesMoodAndReadingCarouselWithoutLayoutJump() throws {
        let app = SeededHomeUITest.application()
        defer { app.terminate() }
        app.launch()
        let home = app.scrollViews["home-scroll"]
        let rail = app.scrollViews["currently-reading-rail"]
        XCTAssertTrue(rail.waitForExistence(timeout: 3))
        rail.swipeLeft(velocity: .slow)
        assertValue("book_kafka", of: rail)
        let carouselFrame = rail.frame

        let mood = app.buttons["home-mood-mood_short"]
        scrollTo(mood, in: home, app: app, direction: .down)
        mood.tap()
        assertValue("Selected", of: mood)
        let moodFrame = mood.frame

        for _ in 0..<3 {
            scrollTo(app.staticTexts["home-lists-anchor"], in: home, app: app, direction: .down)
            scrollTo(app.buttons["reading-today"], in: home, app: app, direction: .up)
            // The rhythm anchor can become visible before the header reaches the true top.
            drag(home, direction: .up)
            assertRestored(rail, to: carouselFrame, in: home, app: app)
            assertValue("book_kafka", of: rail)
            scrollTo(mood, in: home, app: app, direction: .down)
            assertValue("Selected", of: mood)
        }

        // Tab return must not reload the feed or move its currently visible mood anchor.
        let returnFrame = mood.frame
        selectTab("Library", in: app)
        selectTab("Home", in: app)
        assertRestored(mood, to: returnFrame, in: home, app: app)
        assertValue("Selected", of: mood)
        XCTAssertEqual(mood.frame.height, moodFrame.height, accuracy: 2)
        assertNoNetworkRequests(app)
    }

    func testHomeBookPushAndPopRestoresMoodAndVisiblePosition() throws {
        let app = SeededHomeUITest.application()
        defer { app.terminate() }
        app.launch()
        let home = app.scrollViews["home-scroll"]
        let mood = app.buttons["home-mood-mood_short"]
        scrollTo(mood, in: home, app: app, direction: .down)
        mood.tap()
        assertValue("Selected", of: mood)
        let book = app.buttons["home-mood-book-book_kindred"]
        scrollTo(book, in: home, app: app, direction: .down)
        let frame = book.frame

        for _ in 0..<3 {
            book.tap()
            XCTAssertTrue(app.navigationBars["Book"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["Save to Library"].waitForExistence(timeout: 3))
            app.navigationBars["Book"].buttons.firstMatch.tap()
            // No recovery swipe: a reset must fail rather than be repaired by the test.
            assertRestored(book, to: frame, in: home, app: app)
            assertValue("Selected", of: mood)
        }
        assertNoNetworkRequests(app)
    }

    private enum Direction { case down, up }

    private func elapsed(since start: TimeInterval) -> TimeInterval {
        ProcessInfo.processInfo.systemUptime - start
    }

    private func selectTab(_ title: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[title]
        XCTAssertTrue(tab.waitForExistence(timeout: 3))
        tab.tap()
        XCTAssertTrue(tab.isSelected, "The \(title) tab must finish switching before checking retained state.")
    }

    private func assertValue(_ expected: String, of element: XCUIElement,
                             file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 3), file: file, line: line)
        let matches = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: element)
        XCTAssertEqual(XCTWaiter.wait(for: [matches], timeout: 3), .completed,
                       "Expected \(element.identifier) value \(expected), got \(String(describing: element.value)).",
                       file: file, line: line)
    }

    private func assertNoNetworkRequests(_ app: XCUIApplication,
                                         file: StaticString = #filePath, line: UInt = #line) {
        // This app-process counter must include attempted API AND cover requests, even blocked ones.
        let counter = app.descendants(matching: .any)["ui-test-network-request-count"].firstMatch
        XCTAssertTrue(counter.waitForExistence(timeout: 3),
                      "A UI screenshot cannot prove zero requests; expose the test-only network counter.", file: file, line: line)
        XCTAssertEqual(counter.value as? String, "0", "Seeded Home must not attempt network I/O.", file: file, line: line)
    }

    private func fullyVisible(_ element: XCUIElement, in scroll: XCUIElement, app: XCUIApplication) -> Bool {
        guard element.exists, element.isHittable else { return false }
        var viewport = scroll.frame.intersection(app.frame).insetBy(dx: 2, dy: 2)
        if app.tabBars.firstMatch.exists {
            viewport.size.height = max(0, min(viewport.maxY, app.tabBars.firstMatch.frame.minY) - viewport.minY)
        }
        let frame = element.frame
        return frame.width > 0 && frame.height > 0 && frame.intersects(viewport)
            && frame.minY >= viewport.minY && frame.maxY <= viewport.maxY
    }

    private func scrollTo(_ element: XCUIElement, in scroll: XCUIElement, app: XCUIApplication, direction: Direction,
                          file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(scroll.waitForExistence(timeout: 3), file: file, line: line)
        for _ in 0..<8 {
            if fullyVisible(element, in: scroll, app: app) { return }
            drag(scroll, direction: direction)
        }
        XCTAssertTrue(fullyVisible(element, in: scroll, app: app),
                      "Failed to expose anchor \(element.identifier) after 8 bounded drags.", file: file, line: line)
    }

    private func drag(_ scroll: XCUIElement, direction: Direction) {
        // Use the left gutter so a vertical drag cannot be intercepted by a nested book carousel.
        let startY: CGFloat = direction == .down ? 0.8 : 0.25
        let endY: CGFloat = direction == .down ? 0.25 : 0.8
        scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: startY))
            .press(forDuration: 0.05, thenDragTo: scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: endY)), withVelocity: .slow, thenHoldForDuration: 0)
    }

    private func assertRestored(_ element: XCUIElement, to original: CGRect, in scroll: XCUIElement, app: XCUIApplication,
                                file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(element.waitForExistence(timeout: 3), file: file, line: line)
        XCTAssertTrue(fullyVisible(element, in: scroll, app: app),
                      "Previously visible anchor \(element.identifier) disappeared or scrolled away.", file: file, line: line)
        let restored = element.frame
        XCTAssertEqual(restored.minX, original.minX, accuracy: 2, file: file, line: line)
        XCTAssertEqual(restored.minY, original.minY, accuracy: 2, file: file, line: line)
        XCTAssertEqual(restored.width, original.width, accuracy: 2, file: file, line: line)
        XCTAssertEqual(restored.height, original.height, accuracy: 2, file: file, line: line)
    }
}
