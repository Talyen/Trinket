import StoreKitTest
import TrinketFeatureSupport
import XCTest

final class FullGamePerformanceUITests: PerformanceJourneyUITestCase {
    @MainActor
    func testOffer() throws {
        let session = try SKTestSession(configurationFileNamed: "Trinket")
        session.resetToDefaultState()
        session.clearTransactions()
        defer { session.clearTransactions() }
        for iteration in 1 ... repetitionCount {
            launchApp(arguments: TestLaunchArg.performanceArguments(from: TestLaunchArg.allUnseeded() + ["-selectedTab", "options"]))
            assertExistsAfterScroll(AccessibilityID.FullGame.options, requireHittable: true)
            measured("full-game-offer", iteration: iteration) {
                tapButton(AccessibilityID.FullGame.options)
                assertExists(AccessibilityID.FullGame.offer)
                dismissSheet(AccessibilityID.FullGame.offer)
                assertDoesNotExist(AccessibilityID.FullGame.offer)
            }
        }
    }
}
