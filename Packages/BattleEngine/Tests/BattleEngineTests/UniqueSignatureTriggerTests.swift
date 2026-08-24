import Testing
import TrinketContent
import TrinketCore
import TrinketTestSupport
@testable import BattleEngine

// swiftlint:disable file_length

// Unique-item signature mechanics: Bloodfire mirror procs and Leech grants,
// Wardbreaker's purge payoff, and Rimeheart's Freeze-to-Block/Mana engine.
// swiftlint:disable:next type_body_length
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

    @Test func blackfletchDetonatesProjectedBleedAndPoisonWithoutGrowthRolls() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeEnemyEffects: [
                ActiveEffect(id: 1, effect: .bleed(2), remainingTurns: 2, sourceActorID: "hero"),
                ActiveEffect(id: 2, effect: .bleed(3), remainingTurns: 1, sourceActorID: "hero"),
                ActiveEffect(id: 3, effect: .poison(8), remainingTurns: 0, sourceActorID: "hero"),
            ],
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(
                    poisonDecayIncreaseChance: 1,
                    criticalDetonateBleedAndPoison: true
                )
            ))
        )

        battle.withEngineContext { context in
            _ = CombatTriggerEngine.afterCriticalHit(
                to: context.roster.enemy.combatant,
                source: context.roster.hero.combatant,
                in: &context
            )
        }

        try #expect(battle.health(of: battle.enemy) == 72)
        #expect(!battle.activeEffects(of: battle.enemy).contains { effect in
            effect.keyword == .bleed || effect.keyword == .poison
        })
    }

    @Test func blackfletchDoesNothingWithoutBleedOrPoison() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                dot: DotTriggers(criticalDetonateBleedAndPoison: true)
            ))
        )

        let events = battle.withEngineContext { context in
            CombatTriggerEngine.afterCriticalHit(
                to: context.roster.enemy.combatant,
                source: context.roster.hero.combatant,
                in: &context
            )
        }

        try #expect(battle.health(of: battle.enemy) == 100)
        #expect(events.isEmpty)
    }

    @Test func twinCastingDrawsOppositeElementOncePerEmpoweredCard() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            heroMaxMana: 9,
            heroMana: 9,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(empoweredElementDrawOpposite: true)
            )),
            dealOpeningHand: false
        )
        battle.withEngineContext { context in
            context.heroDeck = CombatDeck(abilities: [.slash, .frostbolt, .blizzard])
        }
        var meteor = Ability.meteor

        let events = battle.withEngineContext { context in
            BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &meteor,
                actor: context.roster.hero.combatant,
                context: &context
            )
        }

        #expect(events.count { $0.effectKind == .cardsDrawn } == 1)
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.frostbolt.id])
        #expect(battle.heroDeck.abilities.map(\.id) == [Ability.slash.id, Ability.blizzard.id])
    }

    @Test func twinCastingDrawsBurnAfterEmpoweredFreezeAndToleratesNoMatch() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            heroMaxMana: 6,
            heroMana: 6,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(empoweredElementDrawOpposite: true)
            )),
            dealOpeningHand: false
        )
        battle.withEngineContext { context in
            context.heroDeck = CombatDeck(abilities: [.slash, .fireball])
        }
        var frostbolt = Ability.frostbolt
        battle.withEngineContext { context in
            _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &frostbolt,
                actor: context.roster.hero.combatant,
                context: &context
            )
        }
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.fireball.id])

        var secondFrostbolt = Ability.frostbolt
        let events = battle.withEngineContext { context in
            BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &secondFrostbolt,
                actor: context.roster.hero.combatant,
                context: &context
            )
        }
        #expect(!events.contains { $0.effectKind == .cardsDrawn })
    }

    @Test func twinCastingUsesNormalHandOverflow() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: [],
            heroMaxMana: 3,
            heroMana: 3,
            heroModifiers: CombatModifierProfile(triggers: CombatTraitTriggers(
                mana: ManaTriggers(empoweredElementDrawOpposite: true)
            )),
            dealOpeningHand: false
        )
        for ability in [Ability.slash, .heal, .smite] {
            battle.nextCardID += 1
            battle.hand.append(BattleCard(id: battle.nextCardID, ability: ability, owner: .hero))
        }
        battle.withEngineContext { context in
            context.heroDeck = CombatDeck(abilities: [.frostbolt])
        }
        var meteor = Ability.meteor

        battle.withEngineContext { context in
            _ = BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
                for: &meteor,
                actor: context.roster.hero.combatant,
                context: &context
            )
        }

        #expect(battle.hand.count == BattleHand.maxSize)
        #expect(battle.handBuffer.cards.map(\.ability.id) == [Ability.frostbolt.id])
    }

    @Test func saintfallRetaliatesHealsAndResetsNextRound() {
        let modifiers = CombatModifierProfile(
            healthRestoredBonus: 3,
            blockGainedBonus: 5,
            triggers: CombatTraitTriggers(
                block: BlockTriggers(
                    blockBrokenSaintfallPower: 6,
                    holyDamageBlockFlat: 2
                )
            )
        )
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(maxHealth: 50),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            activeHeroEffects: [ActiveEffect(id: 1, effect: .shield(.block, 1), remainingTurns: 0)],
            heroModifiers: modifiers
        )
        battle.appliesFightPacing = false
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
            _ = context.resolveDamage(.directAbilityHit(
                amount: 2,
                target: context.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: context.roster.enemy.id
            ))
        }

        let firstEnemyHealth = battle.health(of: battle.enemy)
        let firstHeroHealth = battle.health(of: battle.hero)
        let firstHeroBlock = BattleTestFixtures.shieldPoints(for: battle.hero, in: battle)
        #expect(firstEnemyHealth == 88)
        #expect(firstHeroHealth == 38)
        #expect(firstHeroBlock == 7)

        battle.withEngineContext { context in
            _ = context.resolveDamage(.directAbilityHit(
                amount: 8,
                target: context.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: context.roster.enemy.id
            ))
        }
        let secondEnemyHealth = battle.health(of: battle.enemy)
        #expect(secondEnemyHealth == 88)

        battle.withEngineContext { context in
            _ = CombatTriggerEngine.atPlayerTurnStart(in: &context)
            context.roster.setActiveEffects(
                [ActiveEffect(id: 2, effect: .shield(.block, 1), remainingTurns: 0)],
                for: context.roster.hero.combatant
            )
            _ = context.resolveDamage(.directAbilityHit(
                amount: 2,
                target: context.roster.hero.combatant,
                keyword: .physical,
                sourceActorID: context.roster.enemy.id
            ))
        }
        let resetEnemyHealth = battle.health(of: battle.enemy)
        #expect(resetEnemyHealth == 76)
    }

    @Test func goldenVerdictBuildsStunWithoutExtraHealthDamageAndPaysModifiedGold() throws {
        var battle = BattleStateTestFactory.makeBattle(
            hero: hero(),
            companion: BattleTestFixtures.passiveCompanion(),
            enemy: BattleTestFixtures.passiveEnemy(),
            heroModifiers: CombatModifierProfile(
                goldGainedBonus: 2,
                triggers: CombatTraitTriggers(
                    control: ControlTriggers(
                        holyStunBuildupPercent: 1,
                        holyTriggeredStunGoldFlat: 1
                    )
                )
            )
        )
        let threshold = battle.withEngineContext { context in
            ControlMeterEngine.threshold(for: context.roster.enemy.combatant, in: context)
        }
        battle.appliesFightPacing = false

        battle.withEngineContext { context in
            _ = context.resolveDamage(.directAbilityHit(
                amount: threshold - 1,
                target: context.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: context.roster.hero.id
            ))
        }
        let buildup = battle.activeEffects(of: battle.enemy).first {
            $0.keyword == .stun && $0.effect.controlMeterValues != nil
        }?.effect.controlMeterValues?.amount

        #expect(battle.health(of: battle.enemy) == 100 - (threshold - 1))
        #expect(buildup == threshold - 1)
        #expect(!battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(battle.gold == 0)

        battle.withEngineContext { context in
            _ = context.resolveDamage(.directAbilityHit(
                amount: 1,
                target: context.roster.enemy.combatant,
                keyword: .holy,
                sourceActorID: context.roster.hero.id
            ))
        }

        try #expect(battle.health(of: battle.enemy) == 100 - threshold)
        #expect(battle.roster.hasControlStatus(for: battle.enemy, keyword: .stun))
        #expect(battle.gold == 3)
    }
}
