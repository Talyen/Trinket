import TrinketFeatureSupport
import XCTest

final class AppPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testLaunchAnimation() throws {
        try XCTSkipUnless(selected("launch-animation"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance() + ["-frame-metrics-launch"], waitForPreparation: false)
            waitForLaunchPreparation()
            play.assertLoaded()
            finishMeasurement("launch-animation", iteration: iteration)
        }
    }

    @MainActor
    func test00ColdLaunchToPlay() throws {
        try XCTSkipUnless(selected("launch-animation"), "Launch metrics not selected")
        let options = XCTMeasureOptions()
        options.iterationCount = repetitionCount
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            launchApp(arguments: TestLaunchArg.productionTiming(audio: true))
            play.assertLoaded(timeout: 8)
        }
    }

    @MainActor
    func test01TabRoundTrip() throws {
        try XCTSkipUnless(selected("tab-round-trip"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertLoaded()
            let collectionTab = tabCoordinate(named: "Collection")
            let homesteadTab = tabCoordinate(named: "Homestead")
            let optionsTab = tabCoordinate(named: "Options")
            let playTab = tabCoordinate(named: "Play")

            measured("tab-round-trip", iteration: iteration) {
                collectionTab.tap()
                assertExists(AccessibilityID.Screen.collection, timeout: Self.deepLinkTimeout)
                homesteadTab.tap()
                homestead.assertLoaded()
                optionsTab.tap()
                assertExists(AccessibilityID.Screen.options, timeout: Self.deepLinkTimeout)
                playTab.tap()
                play.assertLoaded()
            }
        }
    }

    @MainActor
    func test02CollectionNavigation() throws {
        try XCTSkipUnless(selected("collection-navigation"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
            assertExists(AccessibilityID.Screen.collection, timeout: Self.deepLinkTimeout)
            let card = app.buttons[AccessibilityID.CombatantDetail.collectionCard(name: "Knight")]
            XCTAssertTrue(card.trinketWaitForExistence(timeout: Self.defaultTimeout))
            let cardCoordinate = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dismissStart = sheetDismissDragStart
            let dismissEnd = sheetDismissDragEnd

            measured("collection-navigation", iteration: iteration) {
                cardCoordinate.tap()
                combatantDetail.assertLoaded(for: "Knight")
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
                assertDoesNotExist(AccessibilityID.CombatantDetail.vitalBarsSection)
            }
            assertDoesNotExist(AccessibilityID.CombatantDetail.header(name: "Knight"))
            assertExists(AccessibilityID.Screen.collection, timeout: Self.deepLinkTimeout)
        }
    }

    @MainActor
    func test06StageSelectBattleStart() throws {
        try XCTSkipUnless(selected("stage-select-battle-transition"), "Scenario not selected")
        for iteration in 1 ... repetitionCount {
            let arguments = TestLaunchArg.replacingBattleTickInterval(
                "60",
                in: TestLaunchArg.allForAppPerformance(),
            )
            launchApp(arguments: arguments)
            play.openCampaign()
            let stageAction = button(AccessibilityID.Play.stageAction(chapter: 1, stage: 1))
            XCTAssertTrue(stageAction.trinketWaitForExistence(timeout: Self.defaultTimeout))
            let stageActionCoordinate = stageAction.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5),
            )

            measured("stage-select-battle-transition", iteration: iteration) {
                stageActionCoordinate.tap()
                battle.assertActive(timeout: 8)
            }
        }
    }

    private func tabCoordinate(named name: String) -> XCUICoordinate {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.trinketWaitForExistence(timeout: Self.defaultTimeout))
        return tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }
}
