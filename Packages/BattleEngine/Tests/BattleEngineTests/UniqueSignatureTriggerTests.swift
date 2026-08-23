import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

/// Unique-item signature mechanics: Bloodfire mirror procs and Leech grants,
/// Wardbreaker's purge payoff, and Rimeheart's Freeze-to-Block/Mana engine.
struct UniqueSignatureTriggerTests {
    private func hero(maxHealth: Int = 20) -> Combatant {
        Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: maxHealth, abilities: [])
    }

    @Test func burnTickProcsEqualBleedDamage() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(6), remainingTurns: 2, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(burnProcsBleedChancePercent: 1.0)
            ))
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

        // Burn(6) halves to a 3-point tick; the mirror Bleed hits for the same 3.
        try #expect(battle.health(of: battle.enemy) == 100 - 6)
        #expect(!battle.activeEffects(of: battle.enemy).contains { $0.keyword == .bleed })
    }

    @Test func bleedTickProcsBurnAndChainCapsAtDepth() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .bleed(1), remainingTurns: 3, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    burnProcsBleedChancePercent: 1.0,
                    bleedProcsBurnChancePercent: 1.0
                )
            ))
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

        // Initial Bleed tick plus the capped 5-hop mirror cascade.
        try #expect(battle.health(of: battle.enemy) == 100 - 6)
    }

    @Test func mirrorProcsStayOffWithoutChances() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .burn(3), remainingTurns: 2, sourceActorID: "hero"),
            ]
        )

        _ = BattleTestFixtures.endTurn(on: &battle)

        // Burn(3) halves to a 1-point tick; no mirror procs are configured.
        try #expect(battle.health(of: battle.enemy) == 100 - 1)
    }

    @Test func burnDamageGainsStandardLeech() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(burnDamageLeech: true)
            ))
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        }

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.doTTick(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .burn,
                sourceActorID: context.roster.hero.id
            ))
        }

        let expectedHealing = CombatRounding.scaled(outcome.healthLost, multiplier: Effect.abilityLeechPercent)
        #expect(outcome.healthLost > 0)
        #expect(battle.health(of: battle.hero) == 30 + expectedHealing)
    }

    @Test func bleedDamageGainsStandardLeech() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(bleedDamageLeech: true)
            ))
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        }

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.doTTick(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .bleed,
                sourceActorID: context.roster.hero.id
            ))
        }

        let expectedHealing = CombatRounding.scaled(outcome.healthLost, multiplier: Effect.abilityLeechPercent)
        #expect(outcome.healthLost > 0)
        #expect(battle.health(of: battle.hero) == 30 + expectedHealing)
    }

    @Test func wardbreakerPurgesAllAndDealsHolyPerRemovedEffect() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 6),
                ActiveEffect(id: 2, effect: .thorns(2), remainingTurns: 6),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunPurgeDealHolyPerEffect: 2)
            ))
        )

        let events = battle.withEngineContext { context in
            CombatTriggerEngine.afterEnemyStunned(in: &context)
        }

        try #expect(battle.health(of: battle.enemy) == 100 - 4)
        #expect(events.contains { $0.effectKind == .purgeApplied })
    }

    @Test func wardbreakerHolyIgnoresAttackerBonusesAndMitigatesOnce() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(
                id: "hero",
                name: "Hero",
                role: .hero,
                maxHealth: 20,
                abilities: [],
                primaryStats: PrimaryStats(wisdom: 60)
            ),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 5), remainingTurns: 6),
                ActiveEffect(id: 2, effect: .thorns(2), remainingTurns: 6),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                control: ControlTriggers(stunPurgeDealHolyPerEffect: 2)
            )),
            enemyModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(passiveMitigationFlat: 1)
            ))
        )

        battle.withEngineContext { context in
            CombatTriggerEngine.afterEnemyStunned(in: &context)
        }

        // Flat payload: 2 Holy × 2 effects − 1 mitigation = 3. Wisdom-scaled
        // bonuses or DoT-style re-entry would change this exact number.
        try #expect(battle.health(of: battle.enemy) == 100 - 3)
    }

    @Test func freezeDamageGrantsEqualBlock() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                block: BlockTriggers(freezeDamageGrantsBlock: true)
            ))
        )

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(DamageRequest(
                amount: 4,
                target: context.roster.enemy.combatant,
                keyword: .freeze,
                sourceActorID: context.roster.hero.id
            ))
        }

        try #expect(outcome.healthLost == 4)
        let block = battle.activeEffects(of: battle.hero).first { active in
            if case let .shield(keyword, points) = active.effect {
                return keyword == .block && points == 4
            }
            return false
        }
        #expect(block != nil)
    }

    @Test func freezeBlockUsesPostMitigationHealthLost() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                block: BlockTriggers(freezeDamageGrantsBlock: true)
            )),
            enemyModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mitigation: MitigationTriggers(passiveMitigationFlat: 1)
            ))
        )

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(DamageRequest(
                amount: 5,
                target: context.roster.enemy.combatant,
                keyword: .freeze,
                sourceActorID: context.roster.hero.id
            ))
        }

        // Block tracks health lost after mitigation (4), never raw potency (5).
        try #expect(outcome.healthLost == 4)
        let block = battle.activeEffects(of: battle.hero).first { active in
            if case let .shield(keyword, points) = active.effect {
                return keyword == .block && points == 4
            }
            return false
        }
        #expect(block != nil)
    }

    @Test func danceOfBladesDrawsAndPlaysOnDodge() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgeDrawAndPlayCardChainOnCrit: true)
            )),
            dealOpeningHand: false
        )

        let events = battle.withEngineContext { context -> [ActionEvent] in
            CombatTriggerEngine.afterDodge(
                by: context.roster.hero.combatant,
                attackerID: context.roster.enemy.id,
                in: &context
            )
        }

        #expect(events.contains { $0.effectKind == .cardsDrawn && $0.amount == 1 })
    }

    @Test func danceOfBladesStopsWhenNothingCanBeDrawn() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [.slash],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dodge: DodgeTriggers(onDodgeDrawAndPlayCardChainOnCrit: true)
            )),
            dealOpeningHand: false
        )
        battle.withEngineContext { context in
            context.heroDeck = CombatDeck()
        }

        let events = battle.withEngineContext { context -> [ActionEvent] in
            CombatTriggerEngine.afterDodge(
                by: context.roster.hero.combatant,
                attackerID: context.roster.enemy.id,
                in: &context
            )
        }

        // Empty deck → the auto-play reports didApply == false and the cascade breaks.
        #expect(!events.contains { $0.effectKind == .cardsDrawn })
    }

    @Test func freezingEnemyGrantsManaEqualToBlock() {
        var battle = BattleStateTestFactory.makeBattle(
            hero: Combatant(id: "hero", name: "Hero", role: .hero, maxHealth: 20, maxMana: 10, abilities: []),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeHeroEffects: [
                ActiveEffect(id: 1, effect: .shield(.block, 7), remainingTurns: 6),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(onFreezeEnemyGainManaEqualBlock: true)
            )),
            dealOpeningHand: false
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 0 }
        }

        let events = battle.withEngineContext { context -> [ActionEvent] in
            let threshold = ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
            return ControlMeterEngine.applyMeterCharge(
                threshold,
                keyword: .freeze,
                to: context.roster.enemy.combatant,
                sourceActorID: context.roster.hero.id,
                applyFightPacing: false,
                in: &context
            )
        }

        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .freeze))
        #expect(events.contains { $0.effectKind == .resourceGain && $0.amount == 7 })
        #expect(battle.roster.runtime(for: battle.hero)?.currentMana == 7)
    }
}
