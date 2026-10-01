import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import BattleEngine

struct PassiveTalentCadenceTests {
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
