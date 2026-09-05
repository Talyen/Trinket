import TrinketFeatureSupport
import XCTest

final class AppPerformanceUITests: TrinketUITestCase {
    private static var measurementDuration: TimeInterval {
        isQuick ? 3.2 : 10.5
    }

    private static let samplerWarmup: TimeInterval = 0.85
    private static let reportSettleTimeout: TimeInterval = 12
    private static var minimumCapturedSamples: Int {
        isQuick ? 60 : 90
    }

    private static var isQuick: Bool {
        ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_QUICK"] == "1"
    }

    private var repetitionCount: Int {
        let raw = ProcessInfo.processInfo.environment["TRINKET_PERFORMANCE_REPETITIONS"] ?? "1"
        return max(1, Int(raw) ?? 1)
    }

    func test00ColdLaunchToPlay() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertLoaded(timeout: 8)
        }
    }

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
                self.pauseForTransition()
                homesteadTab.tap()
                self.pauseForTransition()
                optionsTab.tap()
                self.pauseForTransition()
                playTab.tap()
            }
        }
    }

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
                self.pauseForTransition()
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
            }
            collection.assertLoaded()
        }
    }

    func test03HomesteadDetailTransition() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
            homestead.assertLoaded()
            homestead.openFarmingCategoryAndRevealWheatFieldNode()
            let detail = app.descendants(matching: .any)[
                AccessibilityID.Homestead.nodeDetail(title: "Wheat Field"),
            ]
            let isShowingDetail = detail.exists
            let node = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")]
            let nodeCoordinate = node.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let backStart = edgeBackSwipeStart
            let backEnd = edgeBackSwipeEnd

            runOnce(scenario: "homestead-detail-transition", iteration: iteration) {
                if isShowingDetail {
                    backStart.press(forDuration: 0.05, thenDragTo: backEnd)
                } else {
                    nodeCoordinate.tap()
                }
            }
        }
    }

    func test04CampaignStageSelectTransition() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertModeHub()
            let campaign = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: 1)]
            let isShowingCampaign = campaign.exists
            let campaignButton = app.buttons[AccessibilityID.Play.campaignModeCard]
            let campaignCoordinate = campaignButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let backStart = edgeBackSwipeStart
            let backEnd = edgeBackSwipeEnd

            runOnce(scenario: "campaign-stage-select-transition", iteration: iteration) {
                if isShowingCampaign {
                    backStart.press(forDuration: 0.05, thenDragTo: backEnd)
                } else {
                    campaignCoordinate.tap()
                }
            }
            if isShowingCampaign {
                play.assertModeHub()
            } else {
                play.assertCampaignLoaded(number: 1)
            }
        }
    }

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
                self.pauseForTransition()
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
            }
            play.assertCampaignLoaded(number: 1)
        }
    }

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

    private func pauseForTransition() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
    }

    private func runOnce(scenario: String, iteration: Int, action: () -> Void) {
        let reset = app.buttons[AccessibilityID.Debug.frameMetricsReset]
        XCTAssertTrue(reset.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertTrue(metrics.trinketWaitForExistence(timeout: Self.defaultTimeout))
        let resetAt = Date()
        tapWhenReady(reset)
        RunLoop.current.run(until: Date().addingTimeInterval(Self.samplerWarmup))
        action()
        let remaining = Self.measurementDuration - Date().timeIntervalSince(resetAt)
        if remaining > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(remaining))
        }

        let settled = NSPredicate { _, _ in
            let live = self.app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
            guard let payload = live.value as? String,
                  let report = FramePacingReport.parseAccessibilityValue(payload)
            else { return false }
            return report.sampleCount >= Self.minimumCapturedSamples
        }
        XCTAssertEqual(
            XCTWaiter().wait(
                for: [XCTNSPredicateExpectation(predicate: settled, object: metrics)],
                timeout: Self.reportSettleTimeout,
            ),
            .completed,
            "No measured frame report was captured for \(scenario); last=\(metrics.value ?? "nil")",
        )

        let liveMetrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        guard let payload = liveMetrics.value as? String,
              let report = FramePacingReport.parseAccessibilityValue(payload)
        else {
            XCTFail("No measured frame report was captured for \(scenario)")
            return
        }
        XCTAssertGreaterThanOrEqual(report.sampleCount, Self.minimumCapturedSamples)
        PerformanceReportRecorder.record(
            report,
            scenario: scenario,
            suite: "app",
            iteration: iteration,
            in: self,
        )
    }
}
