import TrinketFeatureSupport
import XCTest

struct PlayScreen {
    let app: XCUIApplication

    func assertLoaded(
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Play mode screen not found", file: file, line: line)
    }

    func assertModeHub(
        timeout: TimeInterval = TrinketUITestCase.defaultTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        assertLoaded(timeout: timeout, file: file, line: line)
    }

    func assertCampaignLoaded(
        number: Int = 1,
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: number)]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Campaign Chapter \(number) not found", file: file, line: line)
    }

    func openModeHub() {
        if app.descendants(matching: .any)[AccessibilityID.Play.modesScreen].exists {
            return
        }

        for _ in 0 ..< 4 {
            let back = app.navigationBars.buttons.firstMatch
            guard back.trinketWaitForExistence(timeout: 1) else { break }
            back.trinketTapWhenReady()
            let hub = app.descendants(matching: .any)[AccessibilityID.Play.modesScreen]
            if hub.exists {
                return
            }
        }
        assertModeHub()
    }

    func openCampaign(number: Int = 1) {
        openModeHub()
        let campaign = app.buttons[AccessibilityID.Play.campaignModeCard]
        XCTAssertTrue(
            campaign.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout),
            "Campaign control not found",
        )
        campaign.trinketTapWhenReady()
        assertCampaignLoaded(number: number)
    }

    func openExplore() {
        openModeHub()
        let element = app.buttons[AccessibilityID.Play.exploreModeCard]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout), "Explore control not found")
        element.trinketTapWhenReady()
        assertElementExists(AccessibilityID.Play.exploreHub)
    }

    private func assertElementExists(
        _ identifier: String,
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[identifier]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Element '\(identifier)' not found", file: file, line: line)
    }

    func startBattle(chapter: Int, stage: Int) {
        let party = app.descendants(matching: .any)[AccessibilityID.Play.stagePartyControl]
        XCTAssertTrue(party.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout), "Battle party control not found")

        let start = app.buttons[AccessibilityID.Play.stageAction(chapter: chapter, stage: stage)]
        XCTAssertTrue(start.trinketWaitForExistence(timeout: TrinketUITestCase.defaultTimeout), "Battle CTA not found")
        start.trinketTapWhenReady()

        let hand = app.descendants(matching: .any)[AccessibilityID.Battle.hand]
        let victory = app.descendants(matching: .any)[AccessibilityID.Battle.victory]
        let launched = hand.trinketWaitForExistence(timeout: 12)
            || victory.trinketWaitForExistence(timeout: 2)
        XCTAssertTrue(launched, "Start did not launch battle chrome")
    }
}
