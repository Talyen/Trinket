import TrinketFeatureSupport
import XCTest

struct PlayScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Play mode screen not found", file: file, line: line)
    }

    func assertModeHub(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        assertLoaded(timeout: timeout, file: file, line: line)
    }

    func assertChapterHeader(
        number: Int,
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: number)]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Chapter \(number) header not found", file: file, line: line)
    }

    func assertCampaignLoaded(
        number: Int = 1,
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: number)]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Campaign Chapter \(number) not found", file: file, line: line)
    }

    func openModeHub() {
        if app.descendants(matching: .any)[AccessibilityID.Play.modesScreen].exists {
            return
        }

        // Be tolerant of a caller arriving from a nested Play destination.
        for _ in 0 ..< 4 {
            let back = app.navigationBars.buttons.firstMatch
            guard back.waitForExistence(timeout: 1), back.isHittable else { break }
            back.tap()
            let hub = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen]
            if hub.exists {
                return
            }
        }
        assertModeHub()
    }

    func openCampaign() {
        openModeHub()
        app.buttons[AccessibilityID.Play.campaignModeCard].tap()
    }

    func openExplore() {
        openModeHub()
        app.buttons[AccessibilityID.Play.exploreModeCard].tap()
        assertElementExists(AccessibilityID.Play.exploreHub)
    }

    func openStage(_ actionID: String) {
        app.buttons[actionID].tap()
    }

    private func assertElementExists(
        _ identifier: String,
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Element '\(identifier)' not found", file: file, line: line)
    }

    func openStage(chapter: Int, stage: Int) {
        openStage(AccessibilityID.Play.stageAction(chapter: chapter, stage: stage))
    }

    /// Battle stages expose a compact party control and start directly from the stage CTA.
    func startBattle(chapter: Int, stage: Int) {
        let party = app.descendants(matching: .any)[AccessibilityID.Play.stagePartyControl]
        XCTAssertTrue(party.waitForExistence(timeout: TrinketUITestCase.defaultTimeout), "Battle party control not found")

        let start = app.buttons[AccessibilityID.Play.stageAction(chapter: chapter, stage: stage)]
        XCTAssertTrue(start.waitForExistence(timeout: TrinketUITestCase.defaultTimeout), "Battle CTA not found")
        start.tap()

        // The stage CTA must hand off directly to live battle chrome.
        let hand = app.descendants(matching: .any)[AccessibilityID.Battle.hand]
        let victory = app.descendants(matching: .any)[AccessibilityID.Battle.victory]
        let launched = hand.waitForExistence(timeout: 8)
            || victory.waitForExistence(timeout: 2)
        XCTAssertTrue(launched, "Start did not launch battle chrome")
    }
}
