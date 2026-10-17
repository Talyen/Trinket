import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

extension CombatTriggerTalentDamageTests {
    @Test func `arcane focus adds one to mana empowerment damage`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 3, heroMana: 3,
            heroModifiers: CombatantTalentCatalog.profile(for: ["wizard_mana_t1_1"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        var ability = Ability.frostbolt
        CombatExecutor.run { await BattleTurnEngine.spendManaToEmpowerBurnOrFreezeIfNeeded(
            for: &ability,
            actor: battle.hero,
            context: &battle,
        ) }
        #expect(ability.directDamage == Ability.frostbolt.directDamage + 2)
    }

    @Test(arguments: [0, 2, 10])
    func `blood link transfers only excess leech`(missingHealth: Int) {
        var battle = BattleTestFixtures.makePipelineContext(
            heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_leech_t2_1"]), appliesFightPacing: false,
        )
        battle.roster.mutateRuntime(for: battle.hero) { $0.currentHealth = $0.maxHealth - missingHealth }
        battle.roster.mutateRuntime(for: battle.companion) { $0.currentHealth = 1 }
        _ = CombatExecutor.run { await HealingEngine.leechFromDamage(
            10, sourceActorID: battle.hero.id, target: battle.enemy,
            abilityHasLeech: true, damageKeyword: .physical, in: &battle,
        ) }
        #expect(battle.roster.hero.currentHealth == 50 - max(0, missingHealth - 5))
        #expect(battle.roster.companion.currentHealth == 1 + max(0, 5 - missingHealth))
    }
}

extension CombatTriggerTalentDamageTests {
    @Test func `dark recovery strengthens leech at zero mana`() {
        func restored(mana: Int) -> Int {
            var battle = BattleTestFixtures.makePipelineContext(
                heroModifiers: CombatantTalentCatalog.profile(for: ["warlock_mana_t1_1"]), appliesFightPacing: false,
            )
            battle.roster.hero.currentHealth = 5
            battle.roster.hero.currentMana = mana
            _ = CombatExecutor.run { await HealingEngine.leechFromDamage(
                10, sourceActorID: battle.hero.id, target: battle.enemy,
                abilityHasLeech: true, damageKeyword: .physical, in: &battle,
            ) }
            return battle.roster.hero.currentHealth - 5
        }
        #expect(restored(mana: 0) > restored(mana: 1))
    }
}

extension CombatTriggerTalentDamageTests {
    @Test(arguments: [4, 5, 12])
    func `arcane burst keeps excess after every crossed threshold`(amount: Int) {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 12, heroMana: amount, heroModifiers: .withTriggers { $0.spendManaThresholdAutoPlayCard = 5 },
            dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: Array(repeating: .block, count: amount / 5))
        let payment = battle.payMana(amount, for: battle.hero)
        let events = battle.recordingEvents { battle in await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == amount / 5)
        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == amount % 5)
    }

    @Test func `automatic payment ancestry suppresses recursive arcane burst and then restores`() throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroMaxMana: 6, heroMana: 6, heroModifiers: .withTriggers { $0.spendManaThresholdAutoPlayCard = 3 }, dealOpeningHand: false,
        )
        battle.heroDeck = CombatDeck(abilities: [.kindling])
        let card = BattleCardCombatEngine.deal(.kindling, owner: .hero, context: &battle)
        let events = try battle.playCard(cardID: card.id).events
        #expect(events.count { $0.kind == .ability && $0.abilityID == Ability.kindling.id } == 2)
        #expect(battle.mana(of: battle.hero) == 0)
        #expect(battle.roster.hero.talents.battle.manaSpentTowardAutoPlay == 0)
        #expect(!battle.resolution.isAutomaticPlay)
        battle.restoreManaEmitting(3, to: battle.hero, abilityName: "Refill")
        battle.heroDeck = CombatDeck(abilities: [.block])
        let payment = battle.payMana(3, for: battle.hero)
        let next = battle.recordingEvents { battle in await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }
        #expect(next.count { $0.kind == .ability && $0.abilityID == Ability.block.id } == 1)
    }

    @Test func `mana reactions stop when automatic play defeats the payer`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 3, companionMana: 3, companionModifiers: .withTriggers {
                $0.spendManaThresholdAutoPlayCard = 3
                $0.spendManaRandomDoTFlat = 5
            }, dealOpeningHand: false,
        )
        battle.roster.companion.currentHealth = 1
        battle.roster.companion.hasConsumedDeathsDoor = true
        battle.companionDeck = CombatDeck(abilities: [.slash])
        battle.insertEffect(.thorns(10), to: battle.enemy, sourceID: battle.enemy.id, remainingTurns: 0)
        let payment = battle.payMana(3, for: battle.companion)
        CombatExecutor.run { await CombatTriggerEngine.afterSpendMana(payment, in: &battle) }
        #expect(!battle.roster.companion.isAlive)
        #expect(!battle.roster.hasAffliction(.burn, on: battle.enemy))
        #expect(!battle.roster.enemy.activeEffects.contains { $0.keyword == .freeze })
    }
}

extension CombatTriggerTalentDamageTests {
    @Test func `draw and play preserves automatic ancestry for mana reactions`() {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 6, companionMana: 6,
            companionModifiers: CombatantTalentCatalog.profile(for: ["mana_moth_mana_t3_2"]),
            dealOpeningHand: false, appliesFightPacing: false,
        )
        battle.roster.companion.talents.battle.manaSpentTowardAutoPlay = 3
        battle.companionDeck = CombatDeck(abilities: [.kindling, .block])
        let result = battle.recordingEvents { battle in _ = await EffectApplication(
            effect: .drawAndPlayCards(1),
            ability: Ability(id: "automatic-draw", name: "Automatic Draw", tier: .ultimate),
            source: battle.hero,
            target: battle.companion,
        ).apply(in: &battle) }
        #expect(result.contains { $0.kind == .ability && $0.abilityID == Ability.kindling.id })
        #expect(!result.contains { $0.kind == .ability && $0.abilityID == Ability.block.id })
        #expect(battle.roster.companion.talents.battle.manaSpentTowardAutoPlay == 3)
        #expect(!battle.resolution.isAutomaticPlay)
    }
}
