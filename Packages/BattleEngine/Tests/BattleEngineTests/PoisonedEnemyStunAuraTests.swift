import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PoisonedEnemyStunAuraTests {
    enum Scenario: CaseIterable, Sendable {
        case active, unpoisoned, defeatedHero
    }

    @Test(arguments: ["rogue_poison_t4_1", "druid_poison_t3_2"], Scenario.allCases)
    func `Poison susceptibility strengthens the Companion's Stun only while its Hero lives`(
        talentID: String, scenario: Scenario,
    ) throws {
        let fox = try #require(GameContent.combatant(matching: "fox"))
        var companionProfile = CombatModifierProfile(damageDealtBonus: [.stun: 1])
        companionProfile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(), companion: fox,
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: scenario == .defeatedHero ? 0 : 20,
            heroModifiers: CombatantTalentCatalog.profile(for: [talentID]),
            companionModifiers: companionProfile,
        )
        battle.appliesFightPacing = false
        if scenario != .unpoisoned {
            battle.appendEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        }

        _ = BattleTurnEngine.performAction(
            ability: .bash, actor: battle.companion, abilityTarget: battle.enemy, context: &battle,
        )

        #expect(battle.health(of: battle.enemy) == 96)
        let meter = battle.activeEffects(of: battle.enemy).first { $0.keyword == .stun }?.effect.controlMeterValues
        #expect(meter?.amount == (scenario == .active ? 5 : 4))
        #expect(meter?.threshold == 20)
    }

    @Test func `the Hero's Poison susceptibility applies once to its own Stun`() {
        var battle = BattleTestFixtures.makePipelineContext(
            targetMaxHealth: 100,
            heroModifiers: CombatantTalentCatalog.profile(for: ["rogue_poison_t4_1"]),
        )
        battle.appliesFightPacing = false
        battle.appendEffect(.poison(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)

        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            4, keyword: .stun, to: battle.enemy, sourceActorID: battle.hero.id,
            applyFightPacing: false, in: &battle,
        ) }

        let meter = battle.activeEffects(of: battle.enemy).first { $0.keyword == .stun }?.effect.controlMeterValues
        #expect(meter?.amount == 5)
    }
}
