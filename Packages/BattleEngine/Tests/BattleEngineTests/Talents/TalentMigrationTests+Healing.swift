import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test func `purifyingWaters cleanse heals per effect`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true)))
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = 10 }
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1), ActiveEffect(id: 2, effect: .burn(1), remainingTurns: 1)],
                for: ctx.roster.hero.combatant,
            )
        }
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCleanseAction(
                source: ctx.roster.hero.combatant,
                target: ctx.roster.hero.combatant,
                removedCount: 2,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.hero) > 10)
    }

    @Test func `cleanSlate overheal cleanses`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1)], for: ctx.roster.hero.combatant)
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        }
        _ = battle.withEngineContext { ctx in
            _ = ctx.healEmitting(amount: 10, target: ctx.roster.hero.combatant, source: ctx.roster.hero.combatant, abilityName: "test-heal")
        }
        #expect(!battle.activeEffects(of: battle.hero).contains {
            if case .poison = $0.effect {
                true
            } else {
                false
            }
        })
    }

    @Test func `purifyingWaters triggers via living party not just source`() {
        var battle = makeBattle(
            companionTriggers: CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true)),
        )
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = 10 }
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1)], for: ctx.roster.hero.combatant)
        }
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCleanseAction(
                source: ctx.roster.hero.combatant,
                target: ctx.roster.hero.combatant,
                removedCount: 1,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.hero) > 10)
    }

    @Test func `cleanSlate cleanses once per excess restoration`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 2),
                ActiveEffect(id: 2, effect: .burn(1), remainingTurns: 2),
            ], for: ctx.roster.hero.combatant)
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        }
        _ = battle.withEngineContext { ctx in
            _ = ctx.healEmitting(amount: 10, target: ctx.roster.hero.combatant, source: ctx.roster.hero.combatant, abilityName: "first")
            _ = ctx.healEmitting(amount: 10, target: ctx.roster.hero.combatant, source: ctx.roster.hero.combatant, abilityName: "second")
        }
        let remainingDebuffs = battle.activeEffects(of: battle.hero).count(
            where: { $0.effect.keyword == .poison || $0.effect.keyword == .burn },
        )
        #expect(remainingDebuffs == 0)
    }

    @Test func `purifyingWaters does not heal when enemy cleanses`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(purifyingWaters: true)))
        battle.withEngineContext { ctx in
            ctx.roster.mutateRuntime(for: ctx.roster.enemy.combatant) { $0.currentHealth = 10 }
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .poison(1), remainingTurns: 1)], for: ctx.roster.enemy.combatant)
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            CombatTriggerEngine.afterCleanseAction(
                source: ctx.roster.enemy.combatant,
                target: ctx.roster.enemy.combatant,
                removedCount: 1,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) == enemyHealthBefore)
    }

    @Test func `cleanSlate does not cleanse when enemy overheals`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(cleanSlate: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
            ctx.roster.mutateRuntime(for: ctx.roster.enemy.combatant) { $0.currentHealth = $0.maxHealth - 1 }
        }
        _ = battle.withEngineContext { ctx in
            _ = ctx.healEmitting(
                amount: 10,
                target: ctx.roster.enemy.combatant,
                source: ctx.roster.enemy.combatant,
                abilityName: "test-heal",
            )
        }
        let buffRemains = battle.activeEffects(of: battle.enemy).contains {
            if case .shield = $0.effect {
                true
            } else {
                false
            }
        }
        #expect(buffRemains)
    }

    @Test func `bloodprice heals on attacks against bleeding enemies`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(onAttackBleedingEnemyHeal: 2)))
        battle.appliesFightPacing = false
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2)],
                for: ctx.roster.enemy.combatant,
            )
            ctx.roster.mutateRuntime(for: ctx.roster.hero.combatant) {
                $0.currentHealth = $0.maxHealth - 5
            }
        }
        let missing = battle.maxHealth(of: battle.hero) - battle.health(of: battle.hero)
        _ = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 2,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.physical,
                sourceActorID: ctx.roster.hero.id,
                options: DamageOperation.attack(tier: .skill, scaling: .statsAndItems, accuracy: .normal),
            ))
        }
        #expect(battle.maxHealth(of: battle.hero) - battle.health(of: battle.hero) == missing - 2)
    }

    @Test func `aether shield grants block on first overheal each turn`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(overhealFirstBlockPerTurn: 3)))
        for expected in [3, 3] {
            _ = battle.withEngineContext { ctx in
                _ = HealingEngine.resolveHeal(
                    HealRequest(amount: 5, target: ctx.roster.hero.combatant, sourceActorID: ctx.roster.hero.id, logAs: .silent),
                    in: &ctx,
                )
            }
            #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == expected)
        }
        battle.turnCount += 1
        _ = battle.withEngineContext { ctx in
            _ = HealingEngine.resolveHeal(
                HealRequest(amount: 5, target: ctx.roster.hero.combatant, sourceActorID: ctx.roster.hero.id, logAs: .silent),
                in: &ctx,
            )
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 6)
    }

    @Test func `reclaimed reagents converts overheal to block up to four`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healing: HealingTriggers(overhealShieldCap: 4)))
        battle.appliesFightPacing = false
        _ = battle.withEngineContext { ctx in
            _ = HealingEngine.resolveHeal(
                HealRequest(amount: 10, target: ctx.roster.hero.combatant, sourceActorID: ctx.roster.hero.id, logAs: .silent),
                in: &ctx,
            )
        }
        #expect(BattleTestFixtures.shieldPoints(for: battle.hero, in: battle) == 4)
    }
}
