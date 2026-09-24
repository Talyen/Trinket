import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ImportedAffixBattleTests {
    @Test func `Thornwrought grants Thorns only at battle start`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.startBattleThorns = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: profile,
        )

        let first = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(first.contains { $0.effectKind == .thornsApplied && $0.amount == 1 })
        #expect(thorns(on: battle.hero, in: battle) == 1)
        battle.turnCount = 1
        _ = CombatTriggerEngine.atPlayerTurnStart(in: &battle)
        #expect(thorns(on: battle.hero, in: battle) == 1)
    }

    @Test func `Briarward adds Thorns when Block breaks`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockBrokenThornsFlat = 2
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroModifiers: profile,
        )

        let events = CombatTriggerEngine.afterBlockBroken(
            on: battle.hero, attackerID: battle.enemy.id, in: &battle,
        )
        #expect(events.contains { $0.effectKind == .thornsApplied && $0.amount == 2 })
        #expect(thorns(on: battle.hero, in: battle) == 2)
    }

    @Test func `Barbed increases only an existing Thorns retaliation`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.thornsDamageFlat = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 0)],
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        let outcome = battle.resolveDamage(DamageRequest(
            amount: 2, target: battle.hero, keyword: .physical,
            sourceActorID: battle.enemy.id,
            options: DamageOperation.attack(
                tier: .basic, scaling: .flat, accuracy: .unavoidable, abilityCriticalChanceBonus: -1,
            ),
        ))
        #expect(outcome.events.contains { $0.effectKind == .thornsTriggered && $0.amount == 4 })
        #expect(battle.health(of: battle.enemy) == 36)
        #expect(thorns(on: battle.hero, in: battle) == 0)
    }

    @Test func `Bloodward grants Block equal to Health restored on a successful Leech roll`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.leechBlockChancePercent = 1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroHealth: 10,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false

        let outcome = HealingEngine.leechFromDamage(
            8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle,
        )
        let restored = battle.health(of: battle.hero) - 10
        #expect(outcome.flags.contains(.leeched))
        #expect(restored > 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == restored)
    }

    private func thorns(on combatant: Combatant, in battle: BattleState) -> Int {
        battle.roster.activeEffects(for: combatant).reduce(0) { total, active in
            if case let .thorns(amount) = active.effect {
                return total + amount
            }
            return total
        }
    }
}
