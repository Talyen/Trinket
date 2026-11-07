import TrinketFeatureSupport
import XCTest

final class FullGamePurchaseSmokeTests: FullGameStoreKitUITestCase {
    func testOptionsPurchaseUnlocksFullGame() throws {
        try skipUnavailablePurchaseAutomation()
        try startStoreSession()
        launchApp(arguments: TestLaunchArg.allForTab("options") + ["-coverage-diagnostics"])
        openOptionsOffer()
        tapButton(AccessibilityID.FullGame.purchase)
        assertPurchaseCompletes()
        assertDoesNotExist(AccessibilityID.FullGame.options, timeout: 10)
        assertDoesNotExist(AccessibilityID.FullGame.restore)
        assertFullGameAccess(true)
    }
}
