import XCTest

final class ScrollingPerformanceTests: XCTestCase {
    @MainActor
    func testSeededHomeCleanDataLaunchPerformance() throws {
        let app = SeededHomeUITest.application()
        defer { app.terminate() }
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        // Process-cold and clean app data, not OS/filesystem-cache-cold. No simulator reset is performed.
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            XCTAssertTrue(app.buttons["reading-today"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testSeededHomeWarmDataRelaunchPerformance() throws {
        let app = SeededHomeUITest.application()
        defer { app.terminate() }
        app.launch()
        XCTAssertTrue(app.buttons["reading-today"].waitForExistence(timeout: 5))
        app.terminate()
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "0"
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        // Warm data/caches with a new process, not a foreground/resume measurement.
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            app.launch()
            XCTAssertTrue(app.buttons["reading-today"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor
    func testLargeLibraryStaysLazyAndResponsive() throws {
        let app = XCUIApplication()
        app.launchEnvironment["BOOKFLOW_UI_TESTING"] = "1"
        app.launchEnvironment["BOOKFLOW_RESET_TEST_DATA"] = "1"
        app.launchEnvironment["BOOKFLOW_LARGE_LIBRARY"] = "1"
        app.launch()
        app.buttons["Continue"].tap()
        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.buttons["library-book-stress-0"].waitForExistence(timeout: 5))
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
        let rendered = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'library-book-stress-'"))
        XCTAssertLessThan(rendered.count, 100, "The library should materialize visible rows, not all 1,000 books.")
        app.buttons["Reading"].firstMatch.tap()
        XCTAssertTrue(app.buttons["library-book-stress-0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["library-book-stress-1"].exists)
    }

    @MainActor
    func testHomeScrollingPerformance() throws {
        let app = SeededHomeUITest.application()
        app.launch()
        XCTAssertTrue(app.buttons["reading-today"].waitForExistence(timeout: 5))
        // Warm the complete feed before comparing repeat scrolling runs.
        app.swipeUp(velocity: .fast)
        app.swipeUp(velocity: .fast)
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric,
                          XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            app.swipeUp(velocity: .fast)
            app.swipeUp(velocity: .fast)
            app.swipeDown(velocity: .fast)
            app.swipeDown(velocity: .fast)
        }
    }
}
