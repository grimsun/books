import XCTest

final class BookFlowAppUITests: XCTestCase {
    @MainActor
    func testReadingRhythmLongPressTogglesAndPersists() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["BOOKFLOW_UI_TESTING"] = "1"
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "1"
        app.launch()
        app.buttons["Continue"].tap()
        let today = app.buttons["reading-today"]
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertEqual(today.value as? String, "Not completed")
        today.press(forDuration: 0.6)
        XCTAssertEqual(today.value as? String, "Reading completed")
        app.terminate()
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "0"
        app.launch()
        XCTAssertTrue(today.waitForExistence(timeout: 5))
        XCTAssertEqual(today.value as? String, "Reading completed")
        today.press(forDuration: 0.6)
        XCTAssertEqual(today.value as? String, "Not completed")
    }

    @MainActor
    func testOnboardingLibraryProgressSettingsAndRelaunch() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["BOOKFLOW_UI_TESTING"] = "1"
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "1"
        app.launch()

        app.buttons["Fantasy"].tap()
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Library"].tap()
        app.buttons["Reading"].firstMatch.tap()
        let book = app.buttons["library-book-book_left_hand"]
        XCTAssertTrue(book.waitForExistence(timeout: 5))
        book.tap()
        XCTAssertEqual(app.textFields["readingProgress"].value as? String, "128")
        let progress = app.textFields["readingProgress"]
        progress.tap()
        progress.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "150")
        app.buttons["Update Progress"].tap()
        XCTAssertTrue(app.staticTexts["Progress updated"].waitForExistence(timeout: 3))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Page 150"].waitForExistence(timeout: 3))

        app.tabBars.buttons["Profile"].tap()
        app.buttons["Settings"].tap()
        let rhythm = app.switches["showReadingRhythm"]
        XCTAssertTrue(rhythm.waitForExistence(timeout: 3), app.debugDescription)
        rhythm.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertTrue(NSPredicate(format: "value == '0'").evaluate(with: rhythm))

        app.terminate()
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "0"
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Library"].tap()
        app.buttons["library-book-book_left_hand"].tap()
        XCTAssertEqual(app.textFields["readingProgress"].value as? String, "150")
        app.tabBars.buttons["Profile"].tap()
        app.buttons["Settings"].tap()
        XCTAssertEqual(app.switches["showReadingRhythm"].value as? String, "0")
    }

    @MainActor
    func testSearchOpensBookAndSavesToLibrary() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchEnvironment["BOOKFLOW_UI_TESTING"] = "1"
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "1"
        app.launch()
        app.buttons["Continue"].tap()
        app.tabBars.buttons["Search"].tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Life of Pi")
        let result = app.buttons["search-book-book_life_of_pi"]
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        result.tap()
        app.buttons["Save to Library"].tap()
        XCTAssertTrue(app.staticTexts["Saved to Want to Read"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["library-book-book_life_of_pi"].waitForExistence(timeout: 3))
    }
}
