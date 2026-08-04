//
//  lottoApp2UITestsLaunchTests.swift
//  lottoApp2UITests
//
//  Created by Jarosław Wojtasik on 03/07/2025.
//

import XCTest

// See `lottoApp2UITests` — XCTestCase subclasses opt out of the target's default MainActor isolation.
nonisolated final class lottoApp2UITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Launch smoke test: the sources list renders on a cold start, captured per UI configuration.
    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["MBNet Server"].waitForExistence(timeout: 10),
            "the sources list must render on launch"
        )

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
