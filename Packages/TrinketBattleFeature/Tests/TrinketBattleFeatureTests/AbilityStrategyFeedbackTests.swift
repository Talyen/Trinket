import BattleEngine
import Testing
import TrinketContent
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
                    case .word(.triggered(.freeze)):
                        #expect(item.chipPresentation.text == "Frozen")
                        #expect(item.chipPresentation.trailingStyle == .keyword(.freeze))
                    case .word(.triggered(.stun)):
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

    @Test func `silent cards do not invent zero feedback`() {
        let summary = ActionEvent(
            id: 2, actionID: 1, kind: .ability, actorID: "hero", actorName: "Hero",
            abilityID: Ability.manaPotion.id, abilityName: "Mana Potion", targetID: "hero", targetName: "Hero",
            amount: 0, keyword: .physical,
        )
        let silent = CombatFeedbackPresenter.makeItems(from: [summary], at: .now)
        #expect(silent.isEmpty)
        let gain = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .mana, actionID: 1,
        )
        let visible = CombatFeedbackPresenter.makeItems(from: [gain, summary], at: .now)
        #expect(visible.count == 1)
        #expect(visible.first?.label == .amount(3))
    }
}
