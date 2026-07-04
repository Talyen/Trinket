import XCTest
import BattleEngine
import TrinketCore
import TrinketContent

/// Turn-scheduling and wiring contracts for stun/freeze control meters through
/// full battle ticks.
///
/// Pure meter math: `ControlMeterEngineTests`, `CombatPipelineTests`.
/// Threshold formulas: `PrimaryStatsRulesTests`.
/// Effect summaries: `EffectSummaryBuilderTests`.
/// Turn consumption primitives: `BattleTurnEngineTests`.
/// Full regression pin: `BattleGoldenPathTests.testStunThresholdGoldenPath`.
final class ControlMeterIntegrationTests: XCTestCase {
    func testActionSkipPreventsDamage() {
        for keyword in [Keyword.stun, Keyword.freeze] {
            var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: keyword)
            let hero = battle.hero
            let events = BattleTestFixtures.advanceTicks(6, on: &battle)

            XCTAssertEqual(battle.health(of: hero), hero.maxHealth, "keyword=\(keyword)")
            XCTAssertTrue(
                events.contains(effectKind: .controlActionSkipped, keyword: keyword),
                "keyword=\(keyword)"
            )
        }
    }

    func testActionSkipPersistsUntilActorsTurnThenConsumes() {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        BattleTestFixtures.advanceTicks(5, on: &battle)
        XCTAssertFalse(battle.activeEffects(of: enemy).isEmpty)

        let step = battle.advanceOneStep()
        BattleTestFixtures.assertActionSkipConsumed(step: step, actorID: enemy.id, keyword: .stun)
    }

    func testActionSkipClaimsTurnWithoutAbilityEvent() {
        var battle = BattleTestFixtures.partyWithPendingActionSkip(keyword: .stun)
        let enemy = battle.enemy

        BattleTestFixtures.advanceTicks(5, on: &battle)

        let step = battle.advanceOneStep()
        if case let .acted(actor, events) = step {
            XCTAssertEqual(actor.id, enemy.id)
            XCTAssertTrue(events.contains { $0.effectKind == .controlActionSkipped })
            XCTAssertFalse(events.contains { $0.kind == .ability })
        } else {
            XCTFail("Expected stunned enemy to claim its step")
        }
    }

    func testStunDamageBuildsMeterTriggersAndSkipsNextAction() {
        let hero = BattleTestFixtures.stunAbilityHero(damage: 1)
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5, actionIntervalTicks: 2)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        let events = BattleTestFixtures.advanceTicks(6, on: &battle)

        XCTAssertTrue(events.contains(effectKind: .controlTriggered, keyword: .stun))
        XCTAssertTrue(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        XCTAssertEqual(battle.health(of: battle.hero), hero.maxHealth)
    }

    func testShieldBashAppliesStunSkipAndBlock() {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 20,
            abilities: [.shieldBash]
        )
        let pet = BattleTestFixtures.passiveCombatant(id: "pet", name: "Pet", role: .pet, actionIntervalTicks: 2)
        let enemy = BattleTestFixtures.attackingEnemy(abilities: [.slash], maxHealth: 5, actionIntervalTicks: 2)
        var battle = BattleTestFixtures.standardParty(hero: hero, pet: pet, enemy: enemy)

        BattleTestFixtures.advanceTicks(2, on: &battle)
        XCTAssertTrue(battle.hasHeroEffect { effect in
            if case let .shield(.block, buffer, _) = effect, buffer > 0 { return true }
            return false
        })

        let events = BattleTestFixtures.advanceTicks(4, on: &battle)
        XCTAssertTrue(events.contains(effectKind: .controlActionSkipped, keyword: .stun))
        XCTAssertEqual(battle.health(of: battle.hero), hero.maxHealth)
    }
}
