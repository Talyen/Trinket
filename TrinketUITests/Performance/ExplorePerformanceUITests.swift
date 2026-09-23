import TrinketFeatureSupport
import XCTest

final class ExplorePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testVoyage() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.openExplore()
            assertExistsAfterScroll(AccessibilityID.Voyage.modeCard, requireHittable: true)
            tapButton(AccessibilityID.Voyage.modeCard)
            assertExists(AccessibilityID.Voyage.action("easy"))
            let scrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didBrowse = measured("voyage-browse", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didBrowse {
                verifyScrollProbes(scrollProbes, app.scrollViews.firstMatch)
            }
        }
    }

    @MainActor
    func testSpires() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.assertLoaded()
            measured("explore-hub", iteration: iteration) {
                play.openExplore()
                assertExists(AccessibilityID.Play.exploreHub)
            }
            if selected("spires-browse") || selected("spire-climb") {
                tapButton(AccessibilityID.Play.spiresModeCard)
                assertExists(AccessibilityID.Play.spiresHub)
                let spiresScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
                let didBrowse = measured("spires-browse", iteration: iteration) {
                    performScrollGestures(app.scrollViews.firstMatch)
                }
                if didBrowse {
                    verifyScrollProbes(spiresScrollProbes, app.scrollViews.firstMatch)
                }
                if selected("spire-climb") {
                    scrollUntilVisible(button(AccessibilityID.Play.spireRow("ironVein")), swipingUp: false, requireHittable: true)
                    measured("spire-climb", iteration: iteration) {
                        tapButton(AccessibilityID.Play.spireRow("ironVein"))
                        assertExists(AccessibilityID.Play.spireBeginFloor("ironVein", floor: 1))
                    }
                    let floorScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
                    performScrollGestures(app.scrollViews.firstMatch)
                    verifyScrollProbes(floorScrollProbes, app.scrollViews.firstMatch)
                    goBack()
                    assertExists(AccessibilityID.Play.spiresHub)
                }
            }
        }
    }

    @MainActor
    func testLabyrinth() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg
                .performanceArguments(from: TestLaunchArg.allForScreen("labyrinth-map")) + ["-performance-labyrinth-scroll"])
            if button(AccessibilityID.Play.labyrinthEnter).trinketWaitForExistence(timeout: 3) {
                tapButton(AccessibilityID.Play.labyrinthEnter)
            }
            assertExists(AccessibilityID.Play.labyrinthMap, timeout: 20)
            measured("labyrinth-floor-select", iteration: iteration) {
                tapButton(AccessibilityID.Play.labyrinthFloorMenu)
                tapButton(AccessibilityID.Play.labyrinthFloor(1))
                assertExists(AccessibilityID.Play.labyrinthMap)
            }
            let labyrinthScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didScroll = measured("labyrinth-scroll", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didScroll {
                verifyScrollProbes(labyrinthScrollProbes, app.scrollViews.firstMatch)
            }
            scrollUntilVisible(any(AccessibilityID.Play.labyrinthFloor1EntryNode), swipingUp: false, requireHittable: true)
            measured("labyrinth-inspector", iteration: iteration) {
                tapWhenReady(any(AccessibilityID.Play.labyrinthFloor1EntryNode))
                assertExists(AccessibilityID.Play.labyrinthNodeInspector)
                app.buttons[AccessibilityID.Play.labyrinthDismissSelection].coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.03))
                    .tap()
                assertDoesNotExist(AccessibilityID.Play.labyrinthNodeInspector)
            }
        }
    }

    @MainActor
    func testContracts() {
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.allForAppPerformance())
            play.openExplore()
            assertExistsAfterScroll(AccessibilityID.Play.contractsModeCard, requireHittable: true)
            tapButton(AccessibilityID.Play.contractsModeCard)
            assertExists(AccessibilityID.Play.contractsBoard)
            let contractsScrollProbes = captureScrollProbes(app.scrollViews.firstMatch)
            let didBrowse = measured("contracts-browse", iteration: iteration) {
                performScrollGestures(app.scrollViews.firstMatch)
            }
            if didBrowse {
                verifyScrollProbes(contractsScrollProbes, app.scrollViews.firstMatch)
            }
            assertExistsAfterScroll(AccessibilityID.Play.contractsRefresh, requireHittable: true)
            measured("contracts-refresh", iteration: iteration) {
                tapButton(AccessibilityID.Play.contractsRefresh)
                assertExists(AccessibilityID.Play.contractsBoard)
            }
            assertExistsAfterScroll(AccessibilityID.Play.contractParty("standard"), requireHittable: true)
            measured("contracts-party-picker", iteration: iteration) {
                tapButton(AccessibilityID.Play.contractParty("standard"))
                assertExists(AccessibilityID.Play.battlePartyDone)
                tapButton(AccessibilityID.Play.battlePartyDone)
                assertDoesNotExist(AccessibilityID.Play.battlePartyDone)
            }
            assertExistsAfterScroll(AccessibilityID.Play.contractFight("standard"), requireHittable: true)
            measured("contracts-battle-return", iteration: iteration) {
                tapButton(AccessibilityID.Play.contractFight("standard"))
                battle.assertActive()
                battle.openActions()
                battle.retreatAction.tap()
                battle.defeatLeaveAction.trinketTapWhenReady()
                assertExists(AccessibilityID.Play.contractsBoard)
            }
        }
    }
}
