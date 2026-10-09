import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct ImportedAffixBattleTests {
    private func makeAffixBattle(
        heroHealth: Int? = nil,
        heroEffects: [ActiveEffect] = [],
        modifiers: CombatModifierProfile = .zero,
    ) -> BattleState {
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 40),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 40),
            heroEffects: heroEffects,
            heroHealth: heroHealth,
            heroModifiers: modifiers,
        )
        battle.appliesFightPacing = false
        return battle
    }

    @Test func `Thornwrought grants Thorns only at battle start`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.startBattleThorns = 1
        var battle = makeAffixBattle(modifiers: profile)

        let first = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(first.contains { $0.effectKind == .thornsApplied && $0.amount == 1 })
        #expect(thorns(on: battle.hero, in: battle) == 1)
        battle.turnCount = 1
        _ = CombatExecutor.run { await CombatTriggerEngine.atPlayerTurnStart(in: &battle) }
        #expect(thorns(on: battle.hero, in: battle) == 1)
    }

    @Test func `Briarward adds Thorns when Block breaks`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.blockBrokenThornsFlat = 2
        var battle = makeAffixBattle(modifiers: profile)

        let events = CombatExecutor.run { await CombatTriggerEngine.afterBlockBroken(
            on: battle.hero, attackerID: battle.enemy.id, in: &battle,
        ) }
        #expect(events.contains { $0.effectKind == .thornsApplied && $0.amount == 2 })
        #expect(thorns(on: battle.hero, in: battle) == 2)
    }

    @Test func `Barbed increases only an existing Thorns retaliation`() {
        var profile = CombatModifierProfile.zero
        profile.triggers.thornsDamageFlat = 1
        var battle = makeAffixBattle(
            heroEffects: [ActiveEffect(id: 1, effect: .thorns(3), remainingTurns: 0)],
            modifiers: profile,
        )

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
        var battle = makeAffixBattle(heroHealth: 10, modifiers: profile)

        let outcome = CombatExecutor.run { await HealingEngine.leechFromDamage(
            8, sourceActorID: battle.hero.id, abilityHasLeech: true, in: &battle,
        ) }
        let restored = battle.health(of: battle.hero) - 10
        #expect(outcome.flags.contains(.leeched))
        #expect(restored > 0)
        #expect(DefensePoolEngine.blockPoints(in: battle.roster.hero.activeEffects) == restored)
    }

    @Test(arguments: [false, true])
    func `Holy restoration and defense rewards require a surviving wearer`(finallyDefeated: Bool) throws {
        var profile = CombatModifierProfile.zero
        for id in ["beacon", "sanctum", "absolving"] {
            let affix = try #require(GameContent.itemAffixDefinition(matching: id))
            affix.basic.triggers.apply(to: &profile, abilityName: affix.title)
        }
        profile.triggers.criticalChanceBonus = -1
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20),
            companion: CombatantFixtures.passiveCompanion(maxHealth: 20),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: finallyDefeated ? 1 : 20,
            companionHealth: 5,
            heroModifiers: profile,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.hasConsumedDeathsDoor = true
        battle.appendEffect(.poison(1), to: battle.hero, sourceID: battle.enemy.id, remainingTurns: 0)
        battle.appendEffect(.thorns(8), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)

        _ = battle.resolveDamage(DamageRequest(
            amount: 4, target: battle.enemy, keyword: .holy, sourceActorID: battle.hero.id,
            options: .attack(scaling: .flat, accuracy: .unavoidable),
        ))

        #expect(battle.health(of: battle.enemy) == 96)
        #expect(battle.health(of: battle.hero) == (finallyDefeated ? 0 : 12))
        #expect(battle.health(of: battle.companion) == (finallyDefeated ? 5 : 6))
        #expect(DefensePoolEngine.blockPoints(in: battle.activeEffects(of: battle.hero)) == (finallyDefeated ? 0 : 1))
        #expect(battle.activeEffects(of: battle.hero).contains { $0.effect.kind == .poison } == finallyDefeated)
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
