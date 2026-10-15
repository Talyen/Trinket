import TrinketFeatureSupport
import XCTest

final class LocalizationUITests: FullGameStoreKitUITestCase {
    func testJapaneseScreenshots() throws {
        try captureJourney(language: "ja", region: "ja_JP")
    }

    func testKoreanScreenshots() throws {
        try captureJourney(language: "ko", region: "ko_KR")
    }

    func testGermanScreenshots() throws {
        try captureJourney(language: "de", region: "de_DE")
    }

    func testTraditionalChineseScreenshots() throws {
        try captureJourney(language: "zh-Hant", region: "zh_TW")
    }

    func testFrenchScreenshots() throws {
        try captureJourney(language: "fr", region: "fr_FR")
    }

    func testDoubleLengthScreenshots() throws {
        try captureJourney(language: "en", region: "en_US", doubleLength: true)
    }

    private func captureJourney(language: String, region: String, doubleLength: Bool = false) throws {
        let localeArgs = ["-AppleLanguages", "(\(language))", "-AppleLocale", region]
            + (doubleLength ? ["-NSDoubleLocalizedStrings", "YES"] : [])
        let label = doubleLength ? "en-double" : language
        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("60", in: TestLaunchArg.allForBattle()) + localeArgs)
        battle.assertActive()
        capture(label, screen: "battle-cards")
        let card = battle.frontmostHandCard
        assertExists(card)
        card.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        capture(label, screen: "ability-details")
        app.terminate()

        launchApp(arguments: TestLaunchArg.allForTab("collection") + localeArgs)
        let ranger = button(AccessibilityID.CombatantDetail.collectionCard(name: "Ranger"))
        assertExists(ranger)
        tapWhenReady(ranger)
        combatantDetail.assertLoaded(for: "Ranger")
        capture(label, screen: "progression")
        app.terminate()

        try startStoreSession()
        launchApp(arguments: TestLaunchArg.allForTab("options") + localeArgs)
        assertExists(AccessibilityID.Options.hapticsToggle)
        capture(label, screen: "options")
        openOptionsOffer()
        let purchase = button(AccessibilityID.FullGame.purchase)
        assertExists(purchase)
        XCTAssertTrue(purchase.isHittable, "The purchase action must remain reachable in \(label)")
        if language != "en" {
            XCTAssertFalse(purchase.label.contains("Unlock Full Game"), "StoreKit must preserve the app language in \(label)")
        }
        capture(label, screen: "full-game")
    }

    private func capture(_ locale: String, screen: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Localization-\(locale)-\(screen)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: trinketOnMainActor { app.debugDescription })
        hierarchy.name = "Localization-\(locale)-\(screen)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
