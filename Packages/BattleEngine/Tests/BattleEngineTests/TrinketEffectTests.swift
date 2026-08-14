import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct TrinketEffectTests {
    private func makeBattle(
        heroTriggers: CombatTraitTriggers = CombatTraitTriggers(),
        companionTriggers: CombatTraitTriggers = CombatTraitTriggers(),
        heroAbilities: [Ability] = [.slash, .heal, .smite],
        companionAbilities: [Ability] = [.bash, .fangs, .bloodthorn],
        enemyHealth: Int = 100,
        heroMana: Int = 0,
        seed: UInt64 = BattleTestFixtures.deterministicNonCriticalSeed
    ) -> BattleState {
        let hero = Combatant(
            id: "hero",
            name: "Hero",
            role: .hero,
            maxHealth: 50,
            maxMana: 12,
            abilities: heroAbilities
        )
        let companion = Combatant(
            id: "companion",
            name: "Companion",
            role: .companion,
            maxHealth: 50,
            maxMana: 12,
            abilities: companionAbilities
        )
        let enemy = Combatant(
            id: "enemy",
            name: "Enemy",
            role: .enemy,
            maxHealth: enemyHealth,
            abilities: []
        )
        var battle = BattleState(
            hero: hero,
            companion: companion,
            enemy: enemy,
            heroModifiers: CombatModifierProfile(triggers: heroTriggers),
            companionModifiers: CombatModifierProfile(triggers: companionTriggers),
            rngSeed: seed,
            tracksLog: false,
            dealOpeningHand: false
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: hero) { $0.currentMana = heroMana }
        }
        return battle
    }

    @Test func meteoriteRepeatsNativeManaEmpowerment() throws {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(repeatManaEmpowerment: true),
            heroAbilities: [.fireball],
            heroMana: 8
        )
        battle.drawOpeningHand()
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentMana = 8 }
        }
        let card = try #require(battle.hand.cards.first { $0.ability.id == "fireball" })

        let events = try battle.playCard(cardID: card.id)

        try #expect(battle.mana(of: battle.hero) == 2)
        try #expect(events.contains { $0.kind == .ability && $0.amount == 4 })
    }

    @Test func physicalTrinketsBuildStunAndGrantBlock() throws {
        let triggers = CombatTraitTriggers(
            physicalStunBuildupPercent: 1,
            physicalDamageBlockPercent: 0.5
        )
        var battle = makeBattle(heroTriggers: triggers)

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 6,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id
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

    @Test func sunderingRemovesDoubleBlockWithoutSpillingIntoHealth() throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(sunderingBlockMultiplier: 1))
        battle.withEngineContext { context in
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .shield(.block, 10), remainingTurns: 0)],
                for: context.roster.enemy.combatant
            )
        }
        let healthBefore = battle.health(of: battle.enemy)

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.directAbilityHit(
                amount: 6,
                target: context.roster.enemy.combatant,
                keyword: .physical,
                sourceActorID: context.roster.hero.id
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

    @Test func poisonDamageGainsStandardLeech() {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(poisonDamageLeech: true))
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
        }

        let outcome = battle.withEngineContext { context in
            context.resolveDamage(.doTTick(
                amount: 10,
                target: context.roster.enemy.combatant,
                keyword: .poison,
                sourceActorID: context.roster.hero.id
            ))
        }

        let expectedHealing = CombatRounding.scaled(outcome.healthLost, multiplier: Effect.abilityLeechPercent)
        #expect(outcome.healthLost > 0)
        #expect(battle.health(of: battle.hero) == 30 + expectedHealing)
    }

    @Test(arguments: [(block: 10, thorns: 5), (block: 3, thorns: 2)])
    func blockGainCreatesConsumableThorns(block: Int, thorns: Int) throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(blockGainThornsPercent: 0.5))

        battle.withEngineContext { context in
            _ = context.applyBlock(
                block,
                to: context.roster.hero.combatant,
                source: context.roster.hero.combatant,
                abilityName: "Test"
            )
        }

        try #expect(battle.activeEffects(of: battle.hero).contains {
            guard case let .thorns(amount) = $0.effect else { return false }
            return amount == thorns
        })
    }

    @Test func pacedOpeningHandRecordsTurnStartTrinketEvents() throws {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(goldPerTurn: 1)
        )
        while battle.drawNextOpeningHandCard(rebuildLog: false) {}

        let events = battle.finalizeOpeningHand()

        try #expect(events.contains { $0.abilityName == "Merchant's Favor" && $0.amount == 1 })
        try #expect(battle.events.contains { $0.abilityName == "Merchant's Favor" && $0.amount == 1 })
        try #expect(battle.earnedGold == 1)
    }

    @Test func turnStartTrinketsApplyToTheirWearers() throws {
        let heroTriggers = CombatTraitTriggers(goldPerTurn: 1, healthPerTurn: 2)
        let companionTriggers = CombatTraitTriggers(drawEveryOtherTurn: 1, companionCardsPerTurn: 1)
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

    @Test func resonantChimesTriggersOnSecondWearerCard() throws {
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(cardsPlayedManaThreshold: 2, cardsPlayedManaFlat: 1),
            heroMana: 0
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

    @Test(arguments: [(restored: 8, rawDamage: 4), (restored: 3, rawDamage: 2)])
    func mortarAndPestleDealsHalfRestoredHealthAsPoison(restored: Int, rawDamage: Int) {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(healthRestoredPoisonPercent: 0.5))
        let expectedDamage = battle.withEngineContext {
            $0.paced(rawDamage, sourceActorID: $0.roster.hero.id)
        }
        let healthBefore = battle.health(of: battle.enemy)

        _ = battle.withEngineContext { context in
            CombatTriggerEngine.afterHealthRestored(
                restored,
                to: context.roster.hero.combatant,
                in: &context
            )
        }

        #expect(battle.health(of: battle.enemy) == healthBefore - expectedDamage)
    }

    @Test func frozenPocketwatchQueuesSecondActionSkip() throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(freezeExtraActionSkips: 1))
        battle.withEngineContext { context in
            _ = ControlMeterEngine.applyMeterCharge(
                100,
                keyword: .freeze,
                to: context.roster.enemy.combatant,
                sourceActorID: context.roster.hero.id,
                in: &context
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

    @Test func victoryTrinketsResolveIntoBattleGold() throws {
        var battle = makeBattle(heroTriggers: CombatTraitTriggers(victoryGoldFlat: 4))

        let events = battle.withEngineContext { context in
            CombatTriggerEngine.afterVictory(in: &context)
        }

        try #expect(battle.earnedGold == 4)
        try #expect(events.contains { $0.abilityName == "Smuggler's Map" && $0.amount == 4 })
    }

    @Test func sinEatersLanternHealsTheWearerWhenCleansingAnAlly() throws {
        let cleanseCompanion = Ability(
            id: "cleanse-companion",
            name: "Cleanse Companion",
            tier: .basic,
            targetedEffects: [TargetedEffect(.cleanse(.poison), target: .companion)]
        )
        var battle = makeBattle(
            heroTriggers: CombatTraitTriggers(cleanseSelfHeal: 6),
            heroAbilities: [cleanseCompanion]
        )
        battle.withEngineContext { context in
            context.roster.mutateRuntime(for: context.roster.hero.combatant) { $0.currentHealth = 30 }
            context.roster.setActiveEffects(
                [ActiveEffect(id: 1, effect: .poison(2), remainingTurns: 0)],
                for: context.roster.companion.combatant
            )
        }
        battle.drawOpeningHand()
        let card = try #require(battle.hand.cards.first { $0.ability.id == "cleanse-companion" })

        _ = try battle.playCard(cardID: card.id)

        #expect(battle.health(of: battle.hero) > 30)
        #expect(battle.health(of: battle.companion) == battle.companion.maxHealth)
    }
}
