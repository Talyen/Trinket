import BattleEngine
import Testing
import TrinketContent
import TrinketContentTestSupport
import TrinketCore
@testable import TrinketBattleFeature

struct AbilityStrategyFeedbackTests {
    @Test func `floating vocabulary names freeze and stun alongside icons and numbers`() {
        for outcome in ActionEvent.EffectOutcome.allCases {
            for keyword in Keyword.allCases {
                let event = BattleSessionTestSupport.makeActionEvent(
                    id: 1, kind: .effect, effectKind: outcome, amount: 3, keyword: keyword,
                )
                for item in CombatFeedbackPresenter.makeItems(from: [event], at: .now) {
                    switch item.label {
                    case .word(.plain(.freeze)), .word(.applied(.freeze)), .word(.triggered(.freeze)):
                        #expect(item.chipPresentation.text == "Frozen")
                        #expect(item.chipPresentation.trailingStyle == .keyword(.freeze))
                    case .word(.plain(.stun)), .word(.applied(.stun)), .word(.triggered(.stun)):
                        #expect(item.chipPresentation.text == "Stunned")
                        #expect(item.chipPresentation.trailingStyle == .keyword(.stun))
                    default:
                        #expect(item.chipPresentation.text?.allSatisfy(\.isNumber) ?? true)
                    }
                }
            }
        }
    }

    @Test func `sniff out shows preparation and amount on recipient`() throws {
        let event = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .effect, effectKind: .physicalPreparationApplied, amount: 3, keyword: .physical,
        )
        let item = try #require(CombatFeedbackPresenter.makeItems(from: [event], at: .now).first)
        #expect(item.targetID == event.targetID)
        #expect(item.chipPresentation.leadingStyle == .beneficialStatus)
        #expect(item.chipPresentation.trailingStyle == .keyword(.physical))
        #expect(item.chipPresentation.text == "3")
        #expect(item.label.merging(with: item.label) == nil)
    }

    @Test(arguments: AbilityCatalog.all)
    func `every catalog card produces feedback at full health`(ability: Ability) throws {
        var state = BattleState(
            hero: CombatantFixtures.combatant(id: "hero", role: .hero, maxHealth: 100, abilities: [ability]),
            companion: CombatantFixtures.passiveCompanion(),
            enemy: CombatantFixtures.passiveEnemy(maxHealth: 1000),
            dealOpeningHand: true,
        )
        let card = try #require(state.hand.cards.first { $0.owner == .hero })
        let events = try state.playCard(cardID: card.id)
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        #expect(!items.isEmpty, "Silent card: \(ability.name)")
        if ability.id == Ability.heal.id {
            #expect(items.contains { $0.keyword == .health && $0.label != .amount(0) })
        }
    }

    @Test func `silent fallback does not add zero beside real feedback`() {
        let summary = ActionEvent(
            id: 2, actionID: 1, kind: .ability, actorID: "hero", actorName: "Hero",
            abilityID: Ability.manaPotion.id, abilityName: "Mana Potion", targetID: "hero", targetName: "Hero",
            amount: 0, keyword: .physical,
        )
        let silent = CombatFeedbackPresenter.makeItems(from: [summary], at: .now)
        #expect(silent.count == 1)
        #expect(silent.first?.label == .amount(0))
        #expect(silent.first?.keyword == .mana)
        let gain = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .mana, actionID: 1,
        )
        let visible = CombatFeedbackPresenter.makeItems(from: [gain, summary], at: .now)
        #expect(visible.count == 1)
        #expect(visible.first?.label == .amount(3))
    }
}
