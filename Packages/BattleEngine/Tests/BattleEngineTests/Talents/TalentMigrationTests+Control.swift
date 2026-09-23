import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

extension TalentMigrationTests {
    @Test func `shatterpoint doubles the next bleed damage after stun`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dot: DotTriggers(shatterpoint: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([ActiveEffect(id: 1, effect: .bleed(6), remainingTurns: 2)], for: ctx.roster.enemy.combatant)
        }
        let first = battle.withEngineContext { ctx in
            _ = CombatTriggerEngine.afterEnemyStunned(sourceActorID: ctx.roster.hero.id, in: &ctx)
            return ctx.resolveDamage(DamageRequest(
                amount: 4,
                target: ctx.roster.enemy.combatant,
                keyword: Keyword.bleed,
                sourceActorID: ctx.roster.hero.id,
                options: .reaction(),
            ))
        }
        let second = battle.withEngineContext { ctx in
            ctx.resolveDamage(DamageRequest(
                amount: 4, target: ctx.roster.enemy.combatant, keyword: .bleed,
                sourceActorID: ctx.roster.hero.id, options: .reaction(),
            ))
        }
        #expect(first.healthLost == 8)
        #expect(second.healthLost == 4)
    }

    @Test func `cryostasis preserves bleed on frozen`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dot: DotTriggers(cryostasis: true)))
        let cryoOutcome = battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.enemy.combatant)
            return EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                target: ctx.roster.enemy.combatant,
                battle: &ctx,
            )
        }
        #expect(cryoOutcome.currentEffect?.remainingTurns == 1)
        #expect(cryoOutcome.currentEffect != nil)

        var noCryoBattle = makeBattle()
        let plainOutcome = noCryoBattle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.enemy.combatant)
            return EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                target: ctx.roster.enemy.combatant,
                battle: &ctx,
            )
        }
        #expect((plainOutcome.currentEffect?.remainingTurns ?? 0) == 0)
        #expect(plainOutcome.currentEffect == nil)
    }

    @Test func `crownfall purge deals holy per effect`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(cleanse: CleanseTriggers(crownfall: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            let outcome = BattleTestFixtures.apply(
                .purge(nil),
                abilityName: "purge",
                source: ctx.roster.hero.combatant,
                target: ctx.roster.enemy.combatant,
                in: &ctx,
            )
            _ = outcome
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `crownfall triggers via living party`() {
        var battle = makeBattle(
            companionTriggers: CombatTraitTriggers(cleanse: CleanseTriggers(crownfall: true)),
        )
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.enemy.combatant,
            )
        }
        let enemyHealthBefore = battle.health(of: battle.enemy)
        _ = battle.withEngineContext { ctx in
            _ = BattleTestFixtures.apply(
                .purge(nil),
                abilityName: "purge",
                source: ctx.roster.hero.combatant,
                target: ctx.roster.enemy.combatant,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.enemy) < enemyHealthBefore)
    }

    @Test func `cryostasis does not preserve bleed on frozen ally`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(dot: DotTriggers(cryostasis: true)))
        let outcome = battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects([
                ActiveEffect(id: 1, effect: .controlMeter(Keyword.freeze, 100, 10), remainingTurns: 0),
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
            ], for: ctx.roster.hero.combatant)
            return EffectHandlersTestSupport.dispatchTick(
                ActiveEffect(id: 2, effect: .bleed(4), remainingTurns: 1),
                target: ctx.roster.hero.combatant,
                battle: &ctx,
            )
        }
        #expect((outcome.currentEffect?.remainingTurns ?? 0) == 0)
        #expect(outcome.currentEffect == nil)
    }

    @Test func `crownfall does not damage when enemy purges ally buff`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(cleanse: CleanseTriggers(crownfall: true)))
        battle.withEngineContext { ctx in
            ctx.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 0)],
                for: ctx.roster.hero.combatant,
            )
        }
        let heroHealthBefore = battle.health(of: battle.hero)
        _ = battle.withEngineContext { ctx in
            _ = BattleTestFixtures.apply(
                .purge(nil),
                abilityName: "enemy-purge",
                source: ctx.roster.enemy.combatant,
                target: ctx.roster.hero.combatant,
                in: &ctx,
            )
        }
        #expect(battle.health(of: battle.hero) == heroHealthBefore)
    }

    @Test func `searing bind extends stun against burning enemies`() {
        for burning in [false, true] {
            var battle = makeBattle(heroTriggers: CombatTraitTriggers(control: ControlTriggers(stunExtendVsBurning: true)))
            battle.appliesFightPacing = false
            _ = battle.withEngineContext { ctx in
                if burning {
                    ctx.roster.setActiveEffects(
                        [ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 0)],
                        for: ctx.roster.enemy.combatant,
                    )
                }
                _ = ControlMeterEngine.applyMeterCharge(
                    20, keyword: .stun, to: ctx.roster.enemy.combatant,
                    sourceActorID: ctx.roster.hero.id, applyFightPacing: false, in: &ctx,
                )
            }
            #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
            #expect(battle.additionalControlSkipsByCombatantID[battle.roster.enemy.id, default: 0] == (burning ? 1 : 0))
        }
    }

    @Test func `blizzard triggers at three cards without refreezing on later cards`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(control: ControlTriggers(freezeCardsPlayedThisTurnFreezeAll: 3)))
        let card = Ability(id: "freeze", name: "Freeze", tier: .basic, directDamage: 1, damageKeyword: .freeze)
        for _ in 0 ..< 3 {
            _ = cardReactions(card, in: &battle)
        }
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .freeze))
        battle.roster.setActiveEffects([], for: battle.enemy)
        _ = cardReactions(card, in: &battle)
        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .freeze))
    }
}
