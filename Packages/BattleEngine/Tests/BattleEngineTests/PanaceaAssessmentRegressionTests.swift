import Testing
import TrinketContent
@testable import BattleEngine

struct PanaceaAssessmentRegressionTests {
    @Test(arguments: [false, true])
    func `Panacea healing cue accounts for a preceding Fresh Batch heal`(hasDebuff: Bool) throws {
        var battle = BattleStateTestFactory.makeBattleWithAbilities(
            heroModifiers: CombatantTalentCatalog.profile(for: ["alchemist_cleanse_t1_2"]),
            dealOpeningHand: false,
        )
        battle.appliesFightPacing = false
        battle.roster.hero.currentHealth = 5
        battle.roster.companion.currentHealth = 6
        if hasDebuff {
            battle.appendEffect(.poison(1), to: battle.companion, sourceID: battle.enemy.id, remainingTurns: 2)
        }
        battle.nextCardID += 1
        let card = BattleCard(id: battle.nextCardID, ability: .panaceaPotion, owner: .hero)
        battle.hand.append(card)

        let rng = battle.rng
        let targets = battle.assessCard(card).targets
        #expect(battle.rng == rng)
        #expect(battle.roster.hero.currentHealth == 5)
        #expect(battle.roster.companion.currentHealth == 6)
        #expect(targets.contains { $0.intent == .effect(.cleanse(nil)) })
        let healingTargets = targets.filter {
            if case .effect(.instantHeal(.health, _)) = $0.intent {
                return true
            }
            return false
        }
        #expect(healingTargets.map(\.combatantID) == (hasDebuff ? [] : [battle.hero.id]))

        let events = try battle.playCard(cardID: card.id)
        let heal = try #require(events.first {
            $0.abilityName == Ability.panaceaPotion.name && $0.effectKind == .instantHeal
        })
        #expect(heal.targetID == (hasDebuff ? battle.companion.id : battle.hero.id))
        #expect(events.contains { $0.abilityName == "Fresh Batch" } == hasDebuff)
    }
}
