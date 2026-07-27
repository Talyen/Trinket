import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import BattleEngine
@testable import Trinket

struct CombatFeedbackDensePresentationTests {
    @Test func keepsAllDistinctChipsWithoutOverflowCollapse() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .instantHeal,
                    amount: 2,
                    keyword: .health
                ),
                makeEvent(id: 3, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(
                    id: 4,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: 1,
                    keyword: .gold
                ),
                makeEvent(
                    id: 5,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 3,
                    keyword: .block
                ),
                makeEvent(
                    id: 6,
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    amount: 0,
                    keyword: .dodge
                ),
                makeEvent(
                    id: 7,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: 2,
                    keyword: .mana
                ),
            ],
            at: .now
        )
        // controlApplied is filtered; remaining distinct chips stay individual.
        #expect(items.count == 7)
        #expect(items.allSatisfy { $0.groupResultCount == items.count })
    }

    private func makeEvent(
        id: Int,
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind? = nil,
        amount: Int,
        keyword: Keyword,
        targetID: String = "enemy"
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            actionID: id,
            kind: kind,
            effectKind: effectKind,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "slash",
            abilityName: "Slash",
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword
        )
    }
}
