import TrinketContent
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

    func testSpanishScreenshots() throws {
        try captureJourney(language: "es", region: "es_ES")
    }

    func testBrazilianPortugueseScreenshots() throws {
        try captureJourney(language: "pt-BR", region: "pt_BR")
    }

    func testDoubleLengthScreenshots() throws {
        try captureJourney(language: "en", region: "en_US", doubleLength: true)
    }

    private func captureJourney(language: String, region: String, doubleLength: Bool = false) throws {
        let localeArgs = ["-AppleLanguages", "(\(language))", "-AppleLocale", region]
            + (doubleLength ? ["-NSDoubleLocalizedStrings", "YES"] : [])
        let label = doubleLength ? "en-double" : language
        try captureTalentJourney(label, arguments: localeArgs)

        launchApp(arguments: TestLaunchArg.replacingBattleTickInterval("60", in: TestLaunchArg.allForBattle()) + localeArgs)
        battle.assertActive()
        capture(label, screen: "battle-cards")
        let card = battle.frontmostHandCard
        assertExists(card)
        card.press(forDuration: 0.7)
        assertExists(AccessibilityID.Battle.abilityDetail)
        capture(label, screen: "ability-details")
        dismissSheet(AccessibilityID.Battle.abilityDetail)

        // Battle and Collection render progression through the same CombatantDetailPane.
        battle.openCombatantCard(named: "Ranger")
        combatantDetail.assertLoaded(for: "Ranger")
        capture(label, screen: "progression")
        app.terminate()

        try startStoreSession()
        launchApp(arguments: TestLaunchArg.allForTab("options") + localeArgs)
        XCTAssertTrue(
            scrollUntilVisible(app.switches[AccessibilityID.Options.hapticsToggle], swipingUp: true, requireHittable: true),
            "Options controls must remain reachable in \(label)",
        )
        capture(label, screen: "options")
        openOptionsOffer()
        let purchase = button(AccessibilityID.FullGame.purchase)
        assertExists(purchase)
        XCTAssertTrue(purchase.isHittable, "The purchase action must remain reachable in \(label)")
        if language != "en" {
            XCTAssertFalse(purchase.label.contains("Unlock Full Game"), "StoreKit must preserve the app language in \(label)")
        }
        capture(label, screen: "full-game")
        let offer = app.otherElements[AccessibilityID.FullGame.offer]
        let restore = offer.buttons[AccessibilityID.FullGame.restore]
        let scroll = offer.scrollViews.firstMatch
        var exposedContent = scroll.frame.intersection(app.frame)
        exposedContent.size.height = purchase.frame.minY - exposedContent.minY
        for _ in 0 ..< 12 {
            if restore.exists, restore.isHittable, exposedContent.contains(restore.frame) {
                break
            }
            scroll.dragScroll(fromY: 0.9, toY: 0.35, within: exposedContent)
        }
        XCTAssertTrue(
            restore.isHittable && exposedContent.contains(restore.frame),
            "Restore Purchases must be visible above the pinned purchase action in \(label)",
        )
        XCTAssertTrue(purchase.isHittable, "Scrolling the offer must leave its purchase action reachable")
        capture(label, screen: "full-game-support")
    }

    private func captureTalentJourney(_ locale: String, arguments: [String]) throws {
        launchApp(arguments: TestLaunchArg.allForTab("play")
            + ["-coverage-talent-pair", "-coverage-diagnostics"] + arguments)
        if let expected = ProcessInfo.processInfo.environment["TRINKET_LOCALIZATION_LARGE_TEXT"] {
            let largest = expected == "1"
            waitUntil("Native text size must reach the localized SwiftUI journey") {
                guard let report = try? self.coverageReport() else { return false }
                return report["largestText"] as? Bool == largest
            }
        }
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)
        battle.openActions()
        tapButton(AccessibilityID.Battle.skipCombat)
        assertExists(AccessibilityID.Battle.victory)
        assertExistsAfterScroll(AccessibilityID.Battle.continueButton, requireHittable: true)
        capture(locale, screen: "talent-reward-claim")
        tapButton(AccessibilityID.Battle.continueButton)
        assertExists(AccessibilityID.TalentChoice.screen)
        for combatantID in ["ranger", "wolf"] {
            let tree = try XCTUnwrap(CombatantTalentCatalog.allConfigs[combatantID]?.trees.first)
            let node = try XCTUnwrap(tree.nodes.first)
            XCTAssertTrue(
                scrollUntilVisible(button(AccessibilityID.TalentChoice.tree(id: tree.id)), swipingUp: true, requireHittable: true),
                "The talent tree must remain reachable in \(locale)",
            )
            capture(locale, screen: "talent-\(combatantID)-trees")
            tapButton(AccessibilityID.TalentChoice.tree(id: tree.id))
            tapButton(AccessibilityID.TalentChoice.node(id: node.id))
            assertExistsAfterScroll(AccessibilityID.TalentChoice.unlockButton, requireHittable: true)
            capture(locale, screen: "talent-\(combatantID)-confirm")
            if ProcessInfo.processInfo.environment["TRINKET_LOCALIZATION_LARGE_TEXT"] == "1" {
                let text = ContentCopy.description(node.description, locale: Locale(identifier: locale)).text
                let details = app.scrollViews.containing(.staticText, identifier: text).firstMatch
                assertExists(details)
                for _ in 0 ..< 5 {
                    details.swipeUp()
                }
                capture(locale, screen: "talent-\(combatantID)-rule")
                XCTAssertTrue(
                    button(AccessibilityID.TalentChoice.unlockButton).isHittable,
                    "Reading a long rule must leave its unlock action reachable",
                )
            }
            tapButton(AccessibilityID.TalentChoice.unlockButton)
        }
        play.assertCampaignLoaded()
        let campaign = app.scrollViews[AccessibilityID.Screen.play]
        XCTAssertTrue(
            campaign.frame.minX >= app.frame.minX - 1 && campaign.frame.maxX <= app.frame.maxX + 1,
            "Localized Campaign content must fit the screen horizontally",
        )
        capture(locale, screen: "talent-return")
        app.terminate()
    }

    private func capture(_ locale: String, screen: String) {
        let application: XCUIApplication = app
        let hierarchyText = trinketOnMainActor { application.debugDescription }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Localization-\(locale)-\(screen)"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: hierarchyText)
        hierarchy.name = "Localization-\(locale)-\(screen)-hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
