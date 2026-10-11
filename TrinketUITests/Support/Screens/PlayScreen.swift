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

    func assertCampaignLoaded(
        number: Int = 1,
        timeout: TimeInterval = TrinketUITestCase.deepLinkTimeout,
        file: StaticString = #file,
        line: UInt = #line,
    ) {
        let element = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: number)]
        XCTAssertTrue(element.trinketWaitForExistence(timeout: timeout), "Campaign Chapter \(number) not found", file: file, line: line)
    }

    func openCampaign(number: Int = 1) {
        assertLoaded()
        let campaign = app.buttons[AccessibilityID.Play.campaignModeCard]
        campaign.trinketTapWhenReady()
        assertCampaignLoaded(number: number)
    }

    func openExplore() {
        assertLoaded()
        let element = app.buttons[AccessibilityID.Play.exploreModeCard]
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
        start.trinketTapWhenReady()

        let hand = app.descendants(matching: .any)[AccessibilityID.Battle.hand]
        let victory = app.descendants(matching: .any)[AccessibilityID.Battle.victory]
        let launched = trinketWaitUntil(timeout: TrinketUITestCase.defaultTimeout + 2) {
            hand.exists || victory.exists
        }
        XCTAssertTrue(launched, "Start did not launch battle chrome")
    }
}
