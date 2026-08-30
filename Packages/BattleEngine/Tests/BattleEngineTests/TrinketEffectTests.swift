import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct TrinketEffectTests {
    private func makeBattle(
        heroTriggers: CombatTraitTriggers = CombatTraitTriggers(
        ),
        companionTriggers: CombatTraitTriggers = CombatTraitTriggers(
        ),
        heroAbilities: [Ability] = [.slash, .heal, .smite],
        companionAbilities: [Ability] = [.bash, .fangs, .bloodthorn],
        enemyHealth: Int = 100,
        heroMana: Int = 0,
        initialGold: Int = 0,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed,
    ) -> BattleState {
        BattleStateTestFactory.makeBattleWithAbilities(
            heroAbilities: heroAbilities,
            companionAbilities: companionAbilities,
            enemyMaxHealth: enemyHealth,
            heroMaxMana: 12,
            heroMana: heroMana,
            companionMaxMana: 12,
            initialGold: initialGold,
            heroModifiers: CombatModifierProfile(triggers: heroTriggers),
            companionModifiers: CombatModifierProfile(triggers: companionTriggers),
            rngSeed: seed,
            tracksLog: false,
            dealOpeningHand: false,
        )
    }

    @Test func `meteorite repeats native mana empowerment`() throws {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    repeatManaEmpowerment: true,
                ),
            ),
            heroAbilities: [.fireball],
            heroMana: 8,
        )
        battle.drawOpeningHand()
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 8 }
        }
        let card = try #require(battle.hand.cards.first { $0.ability.id == "fireball" })

        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 2)
        try #expect(events.contains { $0.kind == .ability && $0.amount == 5 })
    }

    @Test func `physical trinkets build stun and grant block`() throws {
        let triggers = CombatTraitTriggers(
            block: BlockTriggers(
                physicalDamageBlockPercent: 0.5,
            ),
            control: ControlTriggers(
                physicalStunBuildupPercent: 1,
            ),
        )
        var battle = makeBattle(heroTriggers: triggers)

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 6,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id,
            ))
        }

        try #expect(outcome.healthLost == 6)
        let enemyEffects = battle.activeEffects(of: battle.enemy)
        try #expect(enemyEffects.contains {
            guard case let .controlMeter(.stun, amount, _) = $0.effect else { return false }
            return amount == 6
        })
        try #expect(battle.activeEffects(of: battle.hero).contains {
            guard case let .shield(.block, amount) = $0.effect else { return false }
            return amount == 3
        })
    }

    @Test func `sundering removes double block without spilling into health`() throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            block: BlockTriggers(
                sunderingBlockMultiplier: 1,
            ),
        ))
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
                for: context.roster.enemy.combatant,
            )
        }
        let healthBefore = battle.health(of: battle.enemy)

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 6,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id,
            ))
        }

        try #expect(outcome.healthLost == 0)
        try #expect(battle.health(of: battle.enemy) == healthBefore)
        #expect(!battle.activeEffects(of: battle.enemy).contains {
            if case .shield = $0.effect {
                true
            } else {
                false
            }
        })
    }

    @Test func `poison damage gains standard leech`() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            dot: DotTriggers(
                poisonDamageLeech: true,
            ),
        ))
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        }

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.doTTick(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .poison,
                sourceActorID: context.roster.hero.id,
            ))
        }

        let expectedHealing = CombatRounding.scaled(outcome.healthLost, multiplier: Effect.abilityLeechPercent)
        #expect(outcome.healthLost > 0)
        #expect(battle.health(of: battle.hero) == 30 + expectedHealing)
    }

    @Test(arguments: [(block: 10, thorns: 5), (block: 3, thorns: 2)])
    func `block gain creates consumable thorns`(block: Int, thorns: Int) throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            block: BlockTriggers(
                blockGainThornsPercent: 0.5,
            ),
        ))

        let outcome = EffectHandlersTestSupport.dispatch(
            .shield(.block, block),
            ability: .block,
            source: battle.hero,
            target: battle.hero,
            battle: &battle,
        )

        try #expect(outcome.didApply)
        try #expect(battle.activeEffects(of: battle.hero).contains {
            guard case let .thorns(amount) = $0.effect else { return false }
            return amount == thorns
        })
    }

    @Test func `paced opening hand records turn start trinket events`() throws {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(
                gold: GoldTriggers(
                    goldPerTurn: 1,
                ),
            ),
        )
        while battle.drawNextOpeningHandCard(rebuildLog: false) {}

        let events = battle.finalizeOpeningHand()

        try #expect(events.contains { $0.abilityName == "Merchant's Favor" && $0.amount == 1 })
        try #expect(battle.events.contains { $0.abilityName == "Merchant's Favor" && $0.amount == 1 })
        try #expect(battle.earnedGold == 1)
    }

    @Test func `turn start trinkets apply to their wearers`() throws {
        let heroTriggers = CombatTraitTriggers(
            gold: GoldTriggers(
                goldPerTurn: 1,
            ),
            healing: HealingTriggers(
                healthPerTurn: 2,
            ),
        )
        let companionTriggers = CombatTraitTriggers(
            mana: ManaTriggers(
                drawEveryOtherTurn: 1,
                companionCardsPerTurn: 1,
            ),
        )
        var battle = makeBattle(heroTriggers: heroTriggers, companionTriggers: companionTriggers)
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 40 }
        }

        let events = battle.withEngineContext { context in
            CombatTriggerEngine.atPlayerTurnStart(in: &context)
        }

        try #expect(battle.earnedGold == 1)
        try #expect(battle.health(of: battle.hero) == 42)
        try #expect(events.filter { $0.effectKind == .cardsDrawn }.reduce(0) { $0 + $1.amount } == 2)
    }

    @Test func `resonant chimes triggers on second wearer card`() throws {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(
                mana: ManaTriggers(
                    cardsPlayedManaThreshold: 2,
                    cardsPlayedManaFlat: 1,
                ),
            ),
            heroMana: 0,
        )

        let first = battle.withEngineContext { context in
            CombatTriggerEngine.afterCardPlayed(by: context.roster.hero.combatant, in: &context)
        }
        let second = battle.withEngineContext { context in
            CombatTriggerEngine.afterCardPlayed(by: context.roster.hero.combatant, in: &context)
        }

        try #expect(first.isEmpty)
        try #expect(second.contains { $0.effectKind == .resourceGain && $0.amount == 1 })
        try #expect(battle.mana(of: battle.hero) == 1)
    }

    @Test func `playful energy heals party after three companion cards without mana affix`() {
        var battle = makeBattle(
            companionTriggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    cardsPlayedHealPartyThreshold: 3,
                    cardsPlayedHealPartyAmount: 2,
                ),
            ),
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 10 }
            context.roster.mutateRuntime(for: context.roster.companion.combatant) { $0.currentHealth = 10 }
        }
        for _ in 0 ..< 3 {
            _ = battle.withEngineContext { context in
                CombatTriggerEngine.afterCardPlayed(by: context.roster.companion.combatant, in: &context)
            }
        }
        _ = battle.withEngineContext { context in
            CombatTriggerEngine.atPlayerEndTurn(in: &context)
        }
        #expect(battle.health(of: battle.hero) == 12)
        #expect(battle.health(of: battle.companion) == 12)
    }

    @Test(arguments: [(restored: 8, rawDamage: 4), (restored: 3, rawDamage: 2)])
    func `mortar and pestle deals half restored health as poison`(restored: Int, rawDamage: Int) {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            healing: HealingTriggers(
                healthRestoredPoisonPercent: 0.5,
            ),
        ))
        let expectedDamage = battle.withEngineContext {
            $0.paced(rawDamage, sourceActorID: $0.roster.hero.id)
        }
        let healthBefore = battle.health(of: battle.enemy)

        _ = battle.withEngineContext { context in
            CombatTriggerEngine.afterHealthRestored(
                restored,
                to: context.roster.hero.combatant,
                in: &context,
            )
        }

        #expect(battle.health(of: battle.enemy) == healthBefore - expectedDamage)
    }

    @Test func `frozen pocketwatch queues second action skip`() throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            control: ControlTriggers(
                freezeExtraActionSkips: 1,
            ),
        ))
        battle.withEngineContext { context in
            _ = ControlMeterEngine.applyMeterCharge(
                100,
                keyword: .freeze,
                to: context.roster.enemy.combatant,
                sourceActorID: context.roster.hero.id,
                in: &context,
            )
        }

        battle.withEngineContext { context in
            _ = BattleTurnEngine.consumeActionSkip(for: context.roster.enemy.combatant, context: &context)
        }
        try #expect(battle.withEngineContext { $0.roster.hasPendingActionSkip(for: $0.roster.enemy.combatant) })

        battle.withEngineContext { context in
            _ = BattleTurnEngine.consumeActionSkip(for: context.roster.enemy.combatant, context: &context)
        }
        try #expect(!battle.withEngineContext { $0.roster.hasPendingActionSkip(for: $0.roster.enemy.combatant) })
    }

    @Test func `victory trinkets resolve into battle gold`() throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(
            gold: GoldTriggers(
                victoryGoldFlat: 4,
            ),
        ))

        let events = battle.withEngineContext { context in
            CombatTriggerEngine.afterVictory(in: &context)
        }

        try #expect(battle.earnedGold == 4)
        try #expect(events.contains { $0.abilityName == "Smuggler's Map" && $0.amount == 4 })
    }

    private struct WishingWellCase: Sendable {
        let initialGold: Int
        let expectedLoss: Int

        static let deductsFullPenalty = Self(initialGold: 5, expectedLoss: -3)
        static let clampsToAvailableGold = Self(initialGold: 1, expectedLoss: -1)
    }

    @Test(arguments: [Self.WishingWellCase.deductsFullPenalty, .clampsToAvailableGold])
    private func `wishing well coin miss deducts gold`(_ testCase: WishingWellCase) throws {
        var foundMiss = false
        for seed in UInt64(0) ..< 32 {
            var battle = makeBattle(
                heroTriggers: CombatTraitTriggers(
                    gold: GoldTriggers(
                        victoryGoldCoin: true,
                    ),
                ),
                initialGold: testCase.initialGold,
                seed: seed,
            )
            let events = battle.withEngineContext { context in
                CombatTriggerEngine.afterVictory(in: &context)
            }
            guard let loss = events.first(where: {
                $0.abilityName == "Wishing Well Coin" && $0.amount < 0
            }) else {
                continue
            }
            try #expect(loss.amount == testCase.expectedLoss)
            try #expect(battle.gold == testCase.initialGold + testCase.expectedLoss)
            try #expect(battle.earnedGold == testCase.expectedLoss)
            foundMiss = true
            break
        }
        try #expect(foundMiss)
    }

    @Test func `sin eaters lantern heals the wearer when cleansing an ally`() throws {
        let cleanseCompanion = Ability(
            id: "cleanse-companion",
            name: "Cleanse Companion",
            tier: .basic,
            targetedEffects: [TargetedEffect(.cleanse(.poison), target: .companion)],
        )
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(
                healing: HealingTriggers(
                    cleanseSelfHeal: 6,
                ),
            ),
            heroAbilities: [cleanseCompanion],
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
                for: context.roster.companion.combatant,
            )
        }
        battle.drawOpeningHand()
        let card = try #require(battle.hand.cards.first { $0.ability.id == "cleanse-companion" })

        _ = try battle.playCard(cardID: card.id)

        #expect(battle.health(of: battle.hero) > 30)
        #expect(battle.health(of: battle.companion) == battle.companion.maxHealth)
    }
}
