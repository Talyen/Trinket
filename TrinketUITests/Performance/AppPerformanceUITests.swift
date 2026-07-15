import XCTest

/// Core app journeys measured with native render-pipeline hitches and the shared
/// refresh-normalized display-link report.
final class AppPerformanceUITests: TrinketUITestCase {
    private static let measurementDuration: TimeInterval = 7.2
    private static let samplerWarmup: TimeInterval = 0.85

    func test00ColdLaunchToPlay() {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertLoaded(timeout: 8)
            app.terminate()
        }
    }

    func test01TabRoundTrip() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance())
        play.assertLoaded()

        run(scenario: "tab-round-trip") {
            self.tabBar.selectCollection()
            self.collection.assertLoaded()
            self.tabBar.selectHomestead()
            self.homestead.assertLoaded()
            self.tabBar.selectOptions()
            self.options.assertLoaded()
            self.tabBar.selectPlay()
            self.play.assertLoaded()
        }
    }

    func test02CollectionNavigation() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "collection"))
        collection.assertLoaded()

        run(scenario: "collection-navigation") {
            self.collection.openCombatantCard(named: "Knight")
            self.combatantDetail.assertLoaded(for: "Knight")
            self.dismissSheet()
            self.collection.assertLoaded()
        }
    }

    func test03HomesteadDetailTransition() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance(tab: "homestead"))
        homestead.assertLoaded()
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Wheat Field"))

        run(scenario: "homestead-detail-transition") {
            let detail = self.app.descendants(matching: .any)[
                AccessibilityID.Homestead.nodeDetail(title: "Wheat Field")
            ]
            if detail.exists {
                self.swipeNavigationBack()
                self.homestead.assertLoaded()
            } else {
                self.homestead.openNode(named: "Wheat Field")
                self.homestead.assertNodeDetail(named: "Wheat Field")
            }
        }
    }

    func test04CampaignStageSelectTransition() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance())
        play.assertModeHub()

        run(scenario: "campaign-stage-select-transition") {
            let campaign = self.app.descendants(matching: .any)[AccessibilityID.Play.chapterHeader(number: 1)]
            if campaign.exists {
                self.swipeNavigationBack()
                self.play.assertModeHub()
            } else {
                self.play.openCampaign()
                self.play.assertCampaignLoaded(number: 1)
            }
        }
    }

    func test05StageEnemyDetailTransition() {
        launchApp(arguments: TestLaunchArg.allForAppPerformance())
        play.openCampaign()
        play.assertCampaignLoaded(number: 1)

        run(scenario: "stage-enemy-detail-transition") {
            self.button(AccessibilityID.Play.enemyArt(chapter: 1, stage: 1)).tap()
            self.combatantDetail.assertLoaded(for: "Slime")
            self.dismissSheet()
            self.play.assertCampaignLoaded(number: 1)
        }
    }

    func test06StageSelectBattleStart() {
        let arguments = TestLaunchArg.replacingBattleTickInterval(
            "60",
            in: TestLaunchArg.allForAppPerformance()
        )
        launchApp(arguments: arguments)
        play.openCampaign()
        play.assertCampaignLoaded(number: 1)

        run(scenario: "stage-select-battle-transition") {
            self.button(AccessibilityID.Play.stageAction(chapter: 1, stage: 1)).tap()
            self.battle.assertActive(timeout: 8)
            RunLoop.current.run(until: Date().addingTimeInterval(1))
            self.battle.openActions()
            XCTAssertTrue(self.battle.retreatAction.waitForExistence(timeout: Self.defaultTimeout))
            self.battle.retreatAction.tap()
            self.play.assertCampaignLoaded(number: 1)
        }
    }

    private func swipeNavigationBack() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.45))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.45))
        start.press(forDuration: 0.05, thenDragTo: end)
    }

    private func run(scenario: String, action: @escaping () -> Void) {
        let options = XCTMeasureOptions()
        options.iterationCount = 1
        var reports: [FramePacingReport] = []
        measure(metrics: [XCTHitchMetric(application: app)], options: options) {
            let reset = self.app.buttons[AccessibilityID.Debug.frameMetricsReset]
            XCTAssertTrue(reset.waitForExistence(timeout: Self.defaultTimeout))
            let metrics = self.app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
            XCTAssertTrue(metrics.waitForExistence(timeout: Self.defaultTimeout))
            let startedAt = Date()
            self.tapWhenReady(reset)
            RunLoop.current.run(until: Date().addingTimeInterval(Self.samplerWarmup))
            action()
            let remaining = Self.measurementDuration - Date().timeIntervalSince(startedAt)
            if remaining > 0 {
                RunLoop.current.run(until: Date().addingTimeInterval(remaining))
            }
            if let payload = metrics.value as? String,
               let report = FramePacingReport.parseAccessibilityValue(payload) {
                reports.append(report)
            }
        }

        XCTAssertFalse(reports.isEmpty)
        for (index, report) in reports.enumerated() {
            XCTAssertGreaterThanOrEqual(report.sampleCount, 120)
            PerformanceReportRecorder.record(
                report,
                scenario: scenario,
                suite: "app",
                iteration: index + 1,
                in: self
            )
        }
    }
}
