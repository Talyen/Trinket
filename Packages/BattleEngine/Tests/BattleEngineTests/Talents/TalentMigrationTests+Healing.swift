import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test(arguments: [
        (BattleParticipant.hero, BattleParticipant.hero, 2),
        (.companion, .hero, 1),
        (.hero, .enemy, 1),
    ])
    func `purifying waters heals cleansed allies from either living party owner`(
        owner: BattleParticipant, recipient: BattleParticipant, removed: Int,
    ) {
        let triggers = CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true))
        var battle = makeBattle(
            heroTriggers: owner == .hero ? triggers : .init(),
            companionTriggers: owner == .companion ? triggers : .init(),
        )
        let target = battle.roster[recipient].combatant
        battle.roster.mutateRuntime(for: target) { $0.currentHealth = 10 }
        battle.roster.setActiveEffects(
            Array([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1),
                   ActiveEffect(id: 2, effect: .burn(1), remainingTurns: 1)].prefix(removed)), for: target,
        )
        _ = CombatExecutor.run { await CombatTriggerEngine.afterCleanseAction(
            source: target, target: target, removedCount: removed, in: &battle,
        ) }
        if recipient == .enemy {
            #expect(battle.health(of: target) == 10)
        } else {
            #expect(battle.health(of: target) > 10)
        }
    }

    @Test(arguments: [1, 2])
    func `clean slate cleanses once per excess restoration`(restorations: Int) {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.roster.setActiveEffects(
            Array([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: restorations),
                   ActiveEffect(id: 2, effect: .burn(1), remainingTurns: restorations)].prefix(restorations)), for: battle.hero,
        )
        battle.roster.hero.currentHealth = battle.roster.hero.maxHealth - 1
        for index in 0 ..< restorations {
            _ = battle.healEmitting(amount: 10, target: battle.hero, source: battle.hero, abilityName: "heal-\(index)")
        }
        #expect(!battle.activeEffects(of: battle.hero).contains { $0.keyword == .poison || $0.keyword == .burn })
    }

    @Test func `cleanSlate does not cleanse when enemy overheals`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
            for: battle.roster.enemy.combatant,
        )
        battle.roster.mutateRuntime(for: battle.roster.enemy.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        _ = battle.healEmitting(
            amount: 10,
            target: battle.roster.enemy.combatant,
            source: battle.roster.enemy.combatant,
            abilityName: "test-heal",
        )
        #expect(battle.activeEffects(of: battle.enemy).contains { $0.effect.kind == .shield })
    }

    @Test func `bloodprice heals on attacks against bleeding enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(onAttackBleedingEnemyHeal: 2)))
        battle.appliesFightPacing = false
        battle.roster.setActiveEffects(
            [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
            for: battle.roster.enemy.combatant,
        )
        battle.roster.mutateRuntime(for: battle.roster.hero.combatant) {
            $0.currentHealth = $0.maxHealth - 5
        }
        let missing = battle.maxHealth(of: battle.hero) - battle.health(of: battle.hero)
        _ = battle.resolveTestDamage(2)
        #expect(battle.maxHealth(of: battle.hero) - battle.health(of: battle.hero) == missing - 2)
    }

    @Test func `aether shield grants block on first overheal each turn`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(overhealFirstBlockPerTurn: 3)))
        for expected in [3, 3] {
            _ = CombatExecutor.run { await HealingEngine.resolveHeal(
                HealRequest(amount: 5, target: battle.roster.hero.combatant, sourceActorID: battle.roster.hero.id, logAs: .silent),
                in: &battle,
            ) }
            #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == expected)
        }
        battle.turnCount += 1
        _ = CombatExecutor.run { await HealingEngine.resolveHeal(
            HealRequest(amount: 5, target: battle.roster.hero.combatant, sourceActorID: battle.roster.hero.id, logAs: .silent),
            in: &battle,
        ) }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 6)
    }

    @Test func `reclaimed reagents converts overheal to block up to four`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(overhealShieldCap: 4)))
        battle.appliesFightPacing = false
        _ = CombatExecutor.run { await HealingEngine.resolveHeal(
            HealRequest(amount: 10, target: battle.roster.hero.combatant, sourceActorID: battle.roster.hero.id, logAs: .silent),
            in: &battle,
        ) }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 4)
    }
}
