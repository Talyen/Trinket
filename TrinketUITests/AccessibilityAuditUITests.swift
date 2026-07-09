import XCTest

/// Accessibility audits for art-heavy surfaces. Skipped unless `TRINKET_RUN_A11Y_AUDITS=1`
/// (nightly integration sets this). Keeps PR/main exhaustive shards journey-focused.
final class AccessibilityAuditUITests: TrinketUITestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        let enabled = ProcessInfo.processInfo.environment["TRINKET_RUN_A11Y_AUDITS"] == "1"
        try XCTSkipUnless(enabled, "Accessibility audits run on nightly integration only")
    }

    func testPlayScreenAccessibility() {
        launchApp(arguments: TestLaunchArg.testLaunchArgs)
        play.assertLoaded()
        assertButtonExists(AccessibilityID.Play.stageNode(chapter: 1, stage: 1))
        assertAccessibilityAudit()
    }

    func testCollectionScreenAccessibility() {
        launchApp(arguments: TestLaunchArg.allForTab("collection"))
        assertExists(AccessibilityID.Collection.heroesCategory)
        assertExists(AccessibilityID.Collection.petsCategory)
        assertExists(AccessibilityID.Collection.inventoryCategory)
        assertAccessibilityAudit()
    }
}
