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
        play.assertLoaded()
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
        assertExistsAfterScroll(AccessibilityID.Homestead.node(title: "Wheat Field"))
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
        if isShowingDetail {
            homestead.assertLoaded()
        } else {
            homestead.assertNodeDetail(named: "Wheat Field")
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

    private func tabCoordinate(named name: String) -> XCUICoordinate {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: Self.defaultTimeout))
        return tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }

    private func pauseForTransition() {
        RunLoop.current.run(until: Date().addingTimeInterval(0.7))
    }

    private func run(scenario: String, action: @escaping () -> Void) {
        let reset = app.buttons[AccessibilityID.Debug.frameMetricsReset]
        XCTAssertTrue(reset.waitForExistence(timeout: Self.defaultTimeout))
        let metrics = app.descendants(matching: .any)[AccessibilityID.Debug.frameMetrics]
        XCTAssertTrue(metrics.waitForExistence(timeout: Self.defaultTimeout))
        let startedAt = Date()
        tapWhenReady(reset)
        RunLoop.current.run(until: Date().addingTimeInterval(Self.samplerWarmup))
        action()
        let remaining = Self.measurementDuration - Date().timeIntervalSince(startedAt)
        if remaining > 0 {
            RunLoop.current.run(until: Date().addingTimeInterval(remaining))
        }
        let populated = NSPredicate { _, _ in
            guard let payload = metrics.value as? String,
                  let report = FramePacingReport.parseAccessibilityValue(payload)
            else { return false }
            return report.sampleCount > 0
        }
        let snapshotExpectation = XCTNSPredicateExpectation(
            predicate: populated,
            object: metrics
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [snapshotExpectation], timeout: Self.defaultTimeout),
            .completed
        )

        guard let payload = metrics.value as? String,
              let report = FramePacingReport.parseAccessibilityValue(payload)
        else {
            XCTFail("No measured frame report was captured for \(scenario)")
            return
        }
        XCTAssertGreaterThanOrEqual(report.sampleCount, 120)
        PerformanceReportRecorder.record(
            report,
            scenario: scenario,
            suite: "app",
            iteration: 1,
            in: self
        )
    }
}
