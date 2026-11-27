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

    /// LTA-37: a blank title rename must put the old name back on screen, and a real one must still show,
    /// trimmed. The system title field changes the bar by itself, so only a UI test can see this.
    @MainActor
    func testRenameFromTheTitle_putsTheOldNameBackWhenBlank_andShowsARealOne() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["Next"].tap()

        // The app keeps its chains between runs, so the names are unique and the chain is deleted afterwards.
        let suffix = String(UUID().uuidString.prefix(6))
        let name = "New chain \(suffix)"
        let newName = "Renamed \(suffix)"
        app.buttons["New chain"].firstMatch.tap()
        let alert = app.alerts["New chain"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.textFields.firstMatch.typeText(" \(suffix)")
        alert.buttons["Create"].tap()
        // The bar's identifier is the title on screen.
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), "the editor opens under the typed name")

        // The title button keeps this label after a rejected rename, even when the bar shows something else.
        let titleButton = app.navigationBars.buttons[name]
        renameFromTitle(titleButton, to: "    ", in: app)
        XCTAssertTrue(app.navigationBars[name].waitForExistence(timeout: 5), "the old name is back in the title")

        renameFromTitle(titleButton, to: "  \(newName)  ", in: app)
        XCTAssertTrue(app.navigationBars[newName].waitForExistence(timeout: 5), "the new name shows, trimmed")

        app.navigationBars.buttons["Chains"].tap()
        let row = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", newName)).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "the list shows the new name")
        row.swipeLeft()
        app.buttons["Delete"].firstMatch.tap()
        app.alerts.buttons["Delete"].tap()
    }

    /// Replaces the title through the system title menu and commits with Return.
    @MainActor
    private func renameFromTitle(_ title: XCUIElement, to text: String, in app: XCUIApplication) {
        title.tap()
        let rename = app.buttons["Rename"]
        XCTAssertTrue(rename.waitForExistence(timeout: 5), "the title menu offers Rename")
        rename.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.typeText("\(text)\n")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
    }

    // `testLaunchPerformance` (Xcode boilerplate) was removed: it relaunched the app five times for ~6
    // minutes, asserted nothing, and destabilised the combined unit+UI run. Launch timing belongs in a
    // dedicated performance run, not in the default test action.
}
