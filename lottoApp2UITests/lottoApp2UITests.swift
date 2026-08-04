//
//  lottoApp2UITests.swift
//  lottoApp2UITests
//
//  Created by Jarosław Wojtasik on 03/07/2025.
//

import XCTest

// `nonisolated`: XCTestCase's overridden members are nonisolated, so the target's default MainActor
// isolation can't apply to the subclass. Individual test methods opt in with @MainActor as usual.
nonisolated final class lottoApp2UITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// SC-001 / SC-007: the MBNet card is on screen at launch and shows every field it is supposed to.
    @MainActor
    func testMBNetCardIsListedAtLaunchWithAllFields() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(
            app.staticTexts["MBNet Server"].waitForExistence(timeout: 5),
            "MBNet must be listed whether or not it has ever synced"
        )
        for label in ["records", "First Record:", "Latest Record:"] {
            XCTAssertTrue(app.staticTexts[label].exists, "card is missing the '\(label)' field")
        }
        XCTAssertTrue(app.buttons.containing(.staticText, identifier: "Refresh").firstMatch.exists,
                      "FR-018: every card provides a Refresh button")
    }

    // `testLaunchPerformance` (Xcode boilerplate) was removed: it relaunched the app five times for ~6
    // minutes, asserted nothing, and destabilised the combined unit+UI run. Launch timing belongs in a
    // dedicated performance run, not in the default test action.
}
