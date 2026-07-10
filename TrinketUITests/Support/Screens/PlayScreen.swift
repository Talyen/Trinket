import XCTest

struct PlayScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Screen.play]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Play screen not found", file: file, line: line)
    }

    func assertModeHub(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen]
        XCTAssertTrue(element.waitForExistence(timeout: timeout), "Mode Hub not found", file: file, line: line)
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

    func openModeHub() {
        // Last mode restores into a pushed destination; pop back to the hub root.
        for _ in 0 ..< 4 {
            let back = app.navigationBars.buttons.element(boundBy: 0)
            guard back.waitForExistence(timeout: 1), back.isHittable else { break }
            back.tap()
            let hub = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen]
            let play = app.descendants(matching: .any)[AccessibilityID.Screen.play]
            if hub.exists, !play.exists { return }
        }
    }

    func openCampaign() {
        openModeHub()
        app.buttons[AccessibilityID.Play.campaignModeCard].tap()
    }

    func openStage(_ nodeID: String) {
        app.buttons[nodeID].tap()
    }

    func openStage(chapter: Int, stage: Int) {
        openStage(AccessibilityID.Play.stageNode(chapter: chapter, stage: stage))
    }

    /// Battle stages open a party sheet first — Start to begin the fight.
    func startBattle(chapter: Int, stage: Int) {
        openStage(chapter: chapter, stage: stage)
        let sheet = app.descendants(matching: .any)[AccessibilityID.Play.battlePartySheet]
        XCTAssertTrue(sheet.waitForExistence(timeout: TrinketUITestCase.defaultTimeout))
        let start = app.descendants(matching: .any)[AccessibilityID.Play.battlePartyStart]
        XCTAssertTrue(start.waitForExistence(timeout: TrinketUITestCase.defaultTimeout), "Battle Party Start not found")
        start.tap()

        // Party sheet must dismiss and hand off to live battle chrome.
        let hand = app.descendants(matching: .any)[AccessibilityID.Battle.hand]
        let victory = app.descendants(matching: .any)[AccessibilityID.Battle.victory]
        let launched = hand.waitForExistence(timeout: TrinketUITestCase.defaultTimeout)
            || victory.waitForExistence(timeout: 1)
        XCTAssertTrue(launched, "Start did not launch battle chrome")
    }
}
