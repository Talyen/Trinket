import TrinketFeatureSupport
import XCTest

final class AppPerformanceUITests: TrinketUITestCase {
    private static var measurementDuration: TimeInterval {
        isQuick ? 3.2 : 10.5
    }

    private static let samplerWarmup: TimeInterval = 0.85

    private static var isQuick: Bool {
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
    }

    private var repetitionCount: Int {
        let raw = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_REPETITIONS"] ?? "1"
        return max(1, Int(raw) ?? 1)
    }

    @MainActor
    func test00ColdLaunchToPlay() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertLoaded(timeout: 8)
        }
    }

    @MainActor
    func test01TabRoundTrip() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertLoaded()
            let collectionTab = tabCoordinate(named: "Collection")
            let homesteadTab = tabCoordinate(named: "Homestead")
            let optionsTab = tabCoordinate(named: "Options")
            let playTab = tabCoordinate(named: "Play")

            runOnce(scenario: "tab-round-trip", iteration: iteration) {
                collectionTab.tap()
                collection.assertLoaded()
                homesteadTab.tap()
                homestead.assertLoaded()
                optionsTab.tap()
                options.assertLoaded()
                playTab.tap()
            }
            play.assertLoaded()
        }
    }

    @MainActor
    func test02CollectionNavigation() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
            collection.assertLoaded()
            let card = app.buttons[AccessibilityID.CombatantDetail.collectionCard(name: "Knight")]
            XCTAssertTrue(card.trinketWaitForExistence(timeout: Self.defaultTimeout))
            let cardCoordinate = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dismissStart = sheetDismissDragStart
            let dismissEnd = sheetDismissDragEnd

            runOnce(scenario: "collection-navigation", iteration: iteration) {
                cardCoordinate.tap()
                combatantDetail.assertLoaded(for: "Knight")
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
            }
            assertDoesNotExist(AccessibilityID.CombatantDetail.header(name: "Knight"))
            collection.assertLoaded()
        }
    }

    @MainActor
    func test03HomesteadDetailTransition() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
            homestead.assertLoaded()
            homestead.openFarmingCategoryAndRevealWheatFieldNode()
            assertExists(AccessibilityID.Homestead.gallery)
            let node = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")]
            let nodeCoordinate = node.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

            runOnce(scenario: "homestead-detail-transition", iteration: iteration) {
                nodeCoordinate.tap()
            }
            homestead.assertNodeDetail(named: "Wheat Field")
        }
    }

    @MainActor
    func test04CampaignStageSelectTransition() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertModeHub()
            let campaignButton = app.buttons[AccessibilityID.Play.campaignModeCard]
            let campaignCoordinate = campaignButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

            runOnce(scenario: "campaign-stage-select-transition", iteration: iteration) {
                campaignCoordinate.tap()
            }
            play.assertCampaignLoaded(number: 1)
        }
    }

    @MainActor
    func test05StageEnemyDetailTransition() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.openCampaign()
            play.assertCampaignLoaded(number: 1)
            let enemy = button(AccessibilityID.Play.enemyArt(chapter: 1, stage: 1))
            XCTAssertTrue(enemy.trinketWaitForExistence(timeout: Self.defaultTimeout))
            let enemyCoordinate = enemy.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let dismissStart = sheetDismissDragStart
            let dismissEnd = sheetDismissDragEnd

            runOnce(scenario: "stage-enemy-detail-transition", iteration: iteration) {
                enemyCoordinate.tap()
                assertExists(AccessibilityID.CombatantDetail.vitalBarsSection)
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
            }
            assertDoesNotExist(AccessibilityID.CombatantDetail.vitalBarsSection)
            play.assertCampaignLoaded(number: 1)
        }
    }

    @MainActor
    func test06StageSelectBattleStart() {
        for iteration in 1 ... repetitionCount {
            let arguments = TestLaunchArg.replacingBattleTickInterval(
                "60",
                in: TestLaunchArg.allForAppPerformance(),
            )
            launchApp(arguments: arguments)
            play.openCampaign()
            play.assertCampaignLoaded(number: 1)
            let stageAction = button(AccessibilityID.Play.stageAction(chapter: 1, stage: 1))
            XCTAssertTrue(stageAction.trinketWaitForExistence(timeout: Self.defaultTimeout))
            let stageActionCoordinate = stageAction.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5),
            )

            runOnce(scenario: "stage-select-battle-transition", iteration: iteration) {
                stageActionCoordinate.tap()
            }
            battle.assertActive(timeout: 8)
        }
    }

    private func tabCoordinate(named name: String) -> XCUICoordinate {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.trinketWaitForExistence(timeout: Self.defaultTimeout))
        return tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    @MainActor
    private func runOnce(scenario: String, iteration: Int, action: () -> Void) {
        let reset = app.buttons[AccessibilityID.Debug.frameMetricsReset]
        XCTAssertTrue(reset.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertTrue(metrics.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let resetAt = Date()
        reset.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        let measuring = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "measuring"),
            object: metrics,
        )
        XCTAssertEqual(XCTWaiter.wait(for: [measuring], timeout: 2), .completed)
        RunLoop.current.run(until: Date().addingTimeInterval(Self.samplerWarmup))
        action()
        let remaining = Self.measurementDuration - Date().timeIntervalSince(resetAt)
        if remaining > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(remaining))
        }

        PerformanceReportRecorder.capture(
            from: app,
            scenario: scenario,
            suite: "app",
            iteration: iteration,
            in: self,
        )
    }
}
