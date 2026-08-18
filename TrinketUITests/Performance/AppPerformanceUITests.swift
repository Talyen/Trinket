import TrinketFeatureSupport
import XCTest

/// Core app journeys measured with native render-pipeline hitches and the shared
/// refresh-normalized display-link report.
final class AppPerformanceUITests: TrinketUITestCase {
    /// Must stay ≥ app `BattlePerformanceTiming.snapshotDelay` (10s full / 3s quick).
    private static var measurementDuration: TimeInterval {
        isQuick ? 3.2 : 10.5
    }

    private static let samplerWarmup: TimeInterval = 0.85
    /// Extra poll after the freeze window for MainActor-delayed snapshot publication.
    private static let reportSettleTimeout: TimeInterval = 12
    /// Capture floor under loaded Simulator refresh (not a hitch budget).
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
        launchApp(arguments: TestLaunchArg.allForAppPerformance())
        play.assertLoaded()
        let collectionTab = tabCoordinate(named: "Collection")
        let homesteadTab = tabCoordinate(named: "Homestead")
        let optionsTab = tabCoordinate(named: "Options")
        let playTab = tabCoordinate(named: "Play")

        run(scenario: "tab-round-trip") {
            collectionTab.tap()
            self.pauseForTransition()
            homesteadTab.tap()
            self.pauseForTransition()
            optionsTab.tap()
            self.pauseForTransition()
            playTab.tap()
        }
    }

    func test02CollectionNavigation() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
        collection.assertLoaded()
        let card = app.buttons[AccessibilityID.CombatantDetail.collectionCard(name: "Knight")]
        XCTAssertTrue(card.waitForExistence(timeout: Self.defaultTimeout))
        let cardCoordinate = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dismissStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let dismissEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))

        run(scenario: "collection-navigation") {
            cardCoordinate.tap()
            self.pauseForTransition()
            dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
        }
        collection.assertLoaded()
    }

    func test03HomesteadDetailTransition() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
        homestead.assertLoaded()
        homestead.openFarmingCategoryAndRevealWheatFieldNode()
        let detail = app.descendants(matching: .any)[
            AccessibilityID.Homestead.nodeDetail(title: "Wheat Field")
        ]
        let isShowingDetail = detail.exists
        let node = app.descendants(matching: .any)[AccessibilityID.Homestead.node(title: "Wheat Field")]
        let nodeCoordinate = node.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let backStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        let backEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))

        run(scenario: "homestead-detail-transition") {
            if isShowingDetail {
                backStart.press(forDuration: 0.05, thenDragTo: backEnd)
            } else {
                nodeCoordinate.tap()
            }
        }
    }

    func test04CampaignStageSelectTransition() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance())
        play.assertModeHub()
        let campaign = app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: 1)]
        let isShowingCampaign = campaign.exists
        let campaignButton = app.buttons[AccessibilityID.Play.campaignModeCard]
        let campaignCoordinate = campaignButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let backStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        let backEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))

        run(scenario: "campaign-stage-select-transition") {
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

    func test05StageEnemyDetailTransition() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance())
        play.openCampaign()
        play.assertCampaignLoaded(number: 1)
        let enemy = button(AccessibilityID.Play.enemyArt(chapter: 1, stage: 1))
        XCTAssertTrue(enemy.waitForExistence(timeout: Self.defaultTimeout))
        let enemyCoordinate = enemy.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let dismissStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18))
        let dismissEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))

        run(scenario: "stage-enemy-detail-transition") {
            enemyCoordinate.tap()
            self.pauseForTransition()
            dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
        }
        play.assertCampaignLoaded(number: 1)
    }

    func test06StageSelectBattleStart() {
        let arguments = TestLaunchArg.replacingBattleTickInterval(
            "60",
            in: TestLaunchArg.allForAppPerformance()
        )
        launchApp(arguments: arguments)
        play.openCampaign()
        play.assertCampaignLoaded(number: 1)
        let stageAction = button(AccessibilityID.Play.stageAction(chapter: 1, stage: 1))
        XCTAssertTrue(stageAction.waitForExistence(timeout: Self.defaultTimeout))
        let stageActionCoordinate = stageAction.coordinate(
            withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        )

        run(scenario: "stage-select-battle-transition") {
            stageActionCoordinate.tap()
        }
        battle.assertActive(timeout: 8)
    }

    func test07VictoryRewardReveal() {
        launchApp(arguments: TestLaunchArg.allForVictoryPerformance())
        let victory = app.descendants(matching: .any)[AccessibilityID.Battle.victory]
        XCTAssertTrue(victory.waitForExistence(timeout: 8))
        run(scenario: "victory-reward-reveal") {
            // Idle on victory chrome while XP bars and reward art settle.
        }
    }

    func test08MysteryEncounterReveal() {
        launchApp(arguments: TestLaunchArg.allForMysteryPerformance())
        // Forced recruit-bear deep link opens on the unlocked reward.
        let unlockCard = app.buttons[AccessibilityID.Mystery.unlockCard(name: "Bear")]
        let unlocked = app.descendants(matching: .any)[AccessibilityID.Mystery.unlockName]
        let appeared = unlockCard.waitForExistence(timeout: 8)
            || unlocked.waitForExistence(timeout: 1)
        XCTAssertTrue(appeared, "Mystery encounter chrome did not appear")
        run(scenario: "mystery-encounter-reveal") {
            // Idle on mystery entrance while artwork and chrome settle.
        }
    }

    private func tabCoordinate(named name: String) -> XCUICoordinate {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: Self.defaultTimeout))
        return tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    private func pauseForTransition() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
    }

    private func run(scenario: String, action: @escaping () -> Void) {
        for iteration in 1 ... repetitionCount {
            runOnce(scenario: scenario, iteration: iteration, action: action)
        }
    }

    private func runOnce(scenario: String, iteration: Int, action: @escaping () -> Void) {
        let reset = app.buttons[AccessibilityID.Debug.frameMetricsReset]
        XCTAssertTrue(reset.waitForExistence(timeout: Self.defaultTimeout))
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertTrue(metrics.waitForExistence(timeout: Self.defaultTimeout))
        let resetAt = Date()
        tapWhenReady(reset)
        RunLoop.current.run(until: Date().addingTimeInterval(Self.samplerWarmup))
        action()
        // Wait out the app's freeze snapshot from reset (probe lives in a
        // top-level UIWindow so covers / shell swaps cannot stale the AX node).
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
                timeout: Self.reportSettleTimeout
            ),
            .completed,
            "No measured frame report was captured for \(scenario); last=\(metrics.value ?? "nil")"
        )

        // Re-query after settle — the pre-wait `metrics` node can go stale across shell swaps.
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
            in: self
        )
    }
}
