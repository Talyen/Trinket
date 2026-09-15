import TrinketFeatureSupport
import XCTest

final class AppPerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testLaunchAnimation() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance() + ["-frame-metrics-launch"], waitForPreparation: false)
            waitForLaunchPreparation()
            play.assertLoaded()
            finishMeasurement("launch-animation", iteration: iteration)
        }
    }

    @MainActor
    func test00ColdLaunchToPlay() {
        let options = XCTMeasureOptions()
        options.iterationCount = repetitionCount
        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
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

            measured("tab-round-trip", iteration: iteration) {
                collectionTab.tap()
                collection.assertLoaded()
                homesteadTab.tap()
                homestead.assertLoaded()
                optionsTab.tap()
                options.assertLoaded()
                playTab.tap()
                play.assertLoaded()
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

            measured("collection-navigation", iteration: iteration) {
                cardCoordinate.tap()
                combatantDetail.assertLoaded(for: "Knight")
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
                assertDoesNotExist(AccessibilityID.CombatantDetail.vitalBarsSection)
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

            measured("homestead-detail-transition", iteration: iteration) {
                nodeCoordinate.tap()
                homestead.assertNodeDetail(named: "Wheat Field")
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

            measured("campaign-stage-select-transition", iteration: iteration) {
                campaignCoordinate.tap()
                play.assertCampaignLoaded(number: 1)
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

            measured("stage-enemy-detail-transition", iteration: iteration) {
                enemyCoordinate.tap()
                assertExists(AccessibilityID.CombatantDetail.vitalBarsSection)
                dismissStart.press(forDuration: 0.1, thenDragTo: dismissEnd)
                assertDoesNotExist(AccessibilityID.CombatantDetail.vitalBarsSection)
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

            measured("stage-select-battle-transition", iteration: iteration) {
                stageActionCoordinate.tap()
                battle.assertActive(timeout: 8)
            }
            battle.assertActive(timeout: 8)
        }
    }

    @MainActor
    func testCampaignBrowsing() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.openCampaign()
            let campaignScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            measured("campaign-scroll", iteration: iteration) { performScrollGestures(app.scrollViews.firstMatch) }
            verifyScrollProbes(campaignScrollProbes, app.scrollViews.firstMatch)
            scrollUntilVisible(button(AccessibilityID.Play.stagePartyControl), swipingUp: false, maxAttempts: 8, requireHittable: true)
            measured("campaign-party-picker", iteration: iteration) {
                tapButton(AccessibilityID.Play.stagePartyControl)
                assertExists(AccessibilityID.Play.battlePartyDone)
                exerciseScroll(horizontalScrollView, horizontal: true)
                app.buttons[AccessibilityID.Play.battlePartyOption(for: "Hero", combatantID: "rogue")].tap()
                tapButton(AccessibilityID.Play.battlePartyDone)
                assertDoesNotExist(AccessibilityID.Play.battlePartyDone)
            }
        }
    }

    private func tabCoordinate(named name: String) -> XCUICoordinate {
        let tab = app.tabBars.buttons[name]
        XCTAssertTrue(tab.trinketWaitForExistence(timeout: Self.defaultTimeout))
        return tab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    }
}
