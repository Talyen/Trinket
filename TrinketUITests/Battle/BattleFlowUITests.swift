import TrinketFeatureSupport
import XCTest

final class BattleFlowUITests: TrinketUITestCase {
    func testSuccessfulCardTapRemovesOneCard() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; covered by the victory test")
        }

        let cards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Hand Card ")
        )
        let countBefore = cards.count
        let card = cards.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.defaultTimeout))
        card.tap()

        let deadline = Date().addingTimeInterval(3)
        while cards.count == countBefore, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(cards.count, countBefore - 1, "A successful tap must remove one card")
    }

    func testSuccessfulCardReleaseRemovesOneCard() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; covered by the victory test")
        }

        let cards = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "Battle Hand Card ")
        )
        let countBefore = cards.count
        let card = cards.firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: Self.defaultTimeout))
        let origin = card.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        origin.press(
            forDuration: 0.05,
            thenDragTo: origin.withOffset(CGVector(dx: 0, dy: -240))
        )

        let deadline = Date().addingTimeInterval(3)
        while cards.count == countBefore, Date() < deadline {
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertEqual(cards.count, countBefore - 1, "A successful play must remove one card")
    }

    /// Hand drag onto a combatant must not open details; tap still works after.
    /// Single owner for this safety invariant (not in smoke).
    func testHandDragReleaseOnCombatantDoesNotOpenDetail() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        battle.assertActive()
        assertExists(battle.hand)

        let hero = app.buttons[AccessibilityID.CombatantDetail.battleCard(name: "Knight")]
        assertExists(hero)

        battle.hand.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: hero.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))

        let detailHeader = combatantDetail.header(for: "Knight")
        XCTAssertFalse(
            detailHeader.waitForExistence(timeout: 1),
            "Releasing a hand-card drag on a combatant must not open details"
        )

        if battle.victory.waitForExistence(timeout: 1) {
            throw XCTSkip("Battle resolved during hand-drag assertions; covered by victory test")
        }

        battle.openCombatantCard(named: "Knight")
        combatantDetail.assertLoaded(for: "Knight")
    }

    /// Victory remains focused on rewards; continue and reward item detail are reachable.
    func testBattleVictorySummaryAndPostVictoryCTA() {
        launchApp(arguments: TestLaunchArg.allForBattleVictory())

        assertExists(battle.victory, timeout: Self.defaultTimeout)
        assertExists(AccessibilityID.Battle.rewards)
        assertExists(AccessibilityID.Battle.experience)
        assertButtonExists(AccessibilityID.Battle.continueButton)

        let rewardItemID = "chapter-1-stage-1-loot"
        assertButtonExists(AccessibilityID.Battle.rewardItem(rewardItemID))
        tapButton(AccessibilityID.Battle.rewardItem(rewardItemID))
        // Sheet + hero header art can take longer under exhaustive suite load than smoke.
        assertExists(AccessibilityID.LoadoutPicker.itemDetail(rewardItemID), timeout: 12)
        dismissSheet()
        assertButtonExists(AccessibilityID.Battle.continueButton)
    }

    func testRetreatRestoresPlayNavigation() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; mid-battle chrome covered by victory test")
        }

        battle.assertActive()
        battle.openActions()
        assertButtonExists(AccessibilityID.Battle.retreat)
        battle.retreatAction.tap()

        XCTAssertTrue(
            app.tabBars.buttons["Play"].waitForExistence(timeout: Self.defaultTimeout),
            "Tab bar should return after retreat"
        )
        play.assertCampaignLoaded(number: 1)
    }

    func testAutoBattleToggleIsVisibleAndReversible() throws {
        launchApp(arguments: TestLaunchArg.allForMidBattle())
        play.openCampaign()
        play.startBattle(chapter: 1, stage: 1)

        if battle.waitForMidBattleOrVictory() {
            throw XCTSkip("Stage 1-1 already resolved; Auto Battle requires active combat")
        }

        let toggle = battle.autoBattleToggle
        XCTAssertTrue(toggle.waitForExistence(timeout: Self.defaultTimeout))
        toggle.tap()
        XCTAssertTrue(toggle.isSelected || (toggle.value as? String) == "1")
        toggle.tap()
        XCTAssertFalse(toggle.isSelected || (toggle.value as? String) == "1")
    }
}
