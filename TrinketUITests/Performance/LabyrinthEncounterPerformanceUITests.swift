import TrinketContent
import TrinketFeatureSupport
import XCTest

final class LabyrinthEncounterPerformanceUITests: PerformanceJourneyUITestCase {
    private func prepareNode(_ type: LabyrinthNodeType, arguments: [String] = []) -> String {
        launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allForScreen("labyrinth-map"))
            + ["-performance-labyrinth-node", type.rawValue] + arguments)
        assertExists(AccessibilityID.Play.labyrinthMap)
        let map = LabyrinthGenerator.makeInitialMap(seed: 0x5452_494E)
        let node = map.nodes.values.sorted { $0.id < $1.id }.first { $0.type == type }
        XCTAssertNotNil(node)
        let identifier = node?.id ?? "missing-fixture"
        let selector = identifier.hasSuffix("-n0") ? AccessibilityID.Play.labyrinthFloor1EntryNode
            :
            (identifier.hasSuffix("-n2") ? AccessibilityID.Play.labyrinthFloor1LockedNode : AccessibilityID.Play
                .labyrinthNode(identifier))
        reveal(any(selector))
        tapWhenReady(any(selector))
        assertExists(AccessibilityID.Play.labyrinthNodeInspector)
        return identifier
    }

    @MainActor
    func testShopEntryReturn() {
        for iteration in 1 ... repetitionCount {
            let node = prepareNode(.shop)
            measured("labyrinth-shop-entry", iteration: iteration) {
                tapButton(AccessibilityID.Play.labyrinthInspectorAction(node))
                assertExists(AccessibilityID.Shop.goldBalance)
            }
            measured("labyrinth-shop-return", iteration: iteration) {
                reveal(button(AccessibilityID.Shop.leaveButton))
                tapButton(AccessibilityID.Shop.leaveButton)
                assertDoesNotExist(AccessibilityID.Shop.goldBalance)
                assertExists(AccessibilityID.Play.labyrinthMap)
            }
        }
    }

    @MainActor
    func testBossEntryReturn() {
        for iteration in 1 ... repetitionCount {
            let node = prepareNode(.boss)
            measured("labyrinth-boss-entry", iteration: iteration) {
                tapButton(AccessibilityID.Play.labyrinthInspectorAction(node))
                battle.assertActive()
            }
            measured("labyrinth-boss-retreat", iteration: iteration) {
                battle.openActions()
                battle.retreatAction.tap()
                battle.retreatConfirmAction.tap()
                assertExists(AccessibilityID.Play.labyrinthMap)
            }
        }
    }

    @MainActor
    func testFloorProgression() {
        for iteration in 1 ... repetitionCount {
            let node = prepareNode(.boss, arguments: ["-performance-outcome-victory"])
            tapButton(AccessibilityID.Play.labyrinthInspectorAction(node))
            battle.assertActive()
            battle.autoBattleToggle.tap()
            assertExists(AccessibilityID.Battle.victory, timeout: 30)
            measured("labyrinth-floor-progression", iteration: iteration) {
                reveal(button(AccessibilityID.Battle.continueButton))
                tapButton(AccessibilityID.Battle.continueButton)
                assertExists(AccessibilityID.Play.labyrinthMap)
                tapButton(AccessibilityID.Play.labyrinthFloorMenu)
                assertExists(AccessibilityID.Play.labyrinthFloor(2))
            }
        }
    }
}
