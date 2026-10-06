import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PassiveTalentCadenceTests {
    @Test(arguments: [false, true])
    func `critical talent rewards remain independent of their feedback names`(sharedName: Bool) throws {
        var profile = CombatModifierProfile.zero
        profile.triggers.burnCriticalRestoreMana = 2
        profile.triggers.bleedCriticalDrawChancePercent = 1
        profile.setTriggerAbilityName("burnCriticalRestoreMana", "Mana Reward")
        profile.setTriggerAbilityName("bleedCriticalDrawChancePercent", sharedName ? "Mana Reward" : "Card Reward")
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            companionMaxMana: 10, companionMana: 0, companionModifiers: profile,
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.companionDeck = CombatDeck(abilities: [.stargaze, .stargaze])
        let attack = Ability(
            id: "critical-reward-cadence", name: "Critical Reward Cadence", tier: .basic,
            damageComponents: [Keyword.burn, .bleed, .burn, .bleed].map { DamageComponent(1, keyword: $0) },
            guaranteedCriticalCondition: .enemyFullHealth,
        )
        let card = BattleCardCombatEngine.deal(attack, owner: .companion, context: &battle)

        let events = try battle.playCard(cardID: card.id)

        #expect(events.count { $0.kind == .abilityDamage && $0.isCritical } == 4)
        #expect(battle.mana(of: battle.companion) == 2)
        #expect(events.count { $0.effectKind == .resourceGain && $0.keyword == .mana && $0.abilityName == "Mana Reward" } == 1)
        #expect(events.count { $0.effectKind == .cardsDrawn } == 1)
        #expect(battle.hand.cards.map(\.ability.id) == [Ability.stargaze.id])
        #expect(battle.companionDeck.count == 1)
    }

    @Test func `font of magic rolls for separate passive mana and health restorations`() {
        var battle = makeBattle()
        let actionCount = battle.actionCount
        let mana = battle.restoreManaEmitting(1, to: battle.hero, abilityName: "Turn Mana")
        let healing = battle.healEmitting(amount: 1, target: battle.hero, source: battle.hero, abilityName: "Verdant Renewal")

        #expect(battle.actionCount == actionCount)
        #expect(battle.roster.hero.currentMana == 1)
        #expect(battle.roster.hero.currentHealth == 11)
        #expect(mana.contains { $0.abilityName == "Font of Magic" && $0.effectKind == .cardsDrawn })
        #expect(healing.contains { $0.abilityName == "Font of Magic" && $0.effectKind == .cardsDrawn })
        #expect(battle.heroDeck.count == 1)
    }

    @Test func `font of magic retains one roll for mana and health within a card`() {
        var battle = makeBattle()
        let card = battle.resolution.beginCard(actorID: battle.hero.id)
        let mana = battle.restoreManaEmitting(1, to: battle.hero, abilityName: "Card Mana")
        let healing = battle.healEmitting(amount: 1, target: battle.hero, source: battle.hero, abilityName: "Card Health")
        battle.resolution.endCard(card)

        #expect(mana.contains { $0.abilityName == "Font of Magic" && $0.effectKind == .cardsDrawn })
        #expect(!healing.contains { $0.abilityName == "Font of Magic" && $0.effectKind == .cardsDrawn })
        #expect(battle.heroDeck.count == 2)
    }

    private func makeBattle() -> BattleState {
        let profile = CombatModifierProfile(triggers: CombatTraitTriggers(healing: HealingTriggers(
            healthOrManaRestoreDrawChancePercent: 1,
        )))
        var battle = BattleStateTestFactory.makeMinimalBattle(
            hero: CombatantFixtures.passiveHero(maxHealth: 20, maxMana: 5),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 100),
            heroHealth: 10, heroMana: 0, heroModifiers: profile,
        )
        battle.heroDeck = CombatDeck(abilities: [.stab, .stab, .stab])
        battle.appliesFightPacing = false
        return battle
    }
}
