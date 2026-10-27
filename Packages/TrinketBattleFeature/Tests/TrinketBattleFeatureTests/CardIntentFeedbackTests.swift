import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CardIntentFeedbackTests {
    @Test func `authored card outcome takes center without promoting a matching passive gain`() throws {
        let events = [
            BattleSessionTestSupport.makeActionEvent(
                id: 1, kind: .effect(.shieldApplied), amount: 5, keyword: .block,
                targetID: "hero", actionID: 1, authoredCardOperation: 0, origin: .automatic,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 2, kind: .effect(.shieldApplied), amount: 2, keyword: .block,
                targetID: "hero", actionID: 1, origin: .automatic,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 3, kind: .effect(.thornsApplied), amount: 3, keyword: .thorns,
                targetID: "hero", actionID: 1, authoredCardOperation: 1, origin: .automatic,
            ),
            BattleSessionTestSupport.makeActionEvent(id: 4, kind: .ability, amount: 0, keyword: .block, actionID: 1),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        let block = try #require(items.first { $0.sourceEventIDs.contains(1) })
        #expect(block.region == .impact)
        #expect(block.label == .amount(5))
        #expect(items.first { $0.sourceEventIDs.contains(2) }?.region == .benefit)
        #expect(items.first { $0.sourceEventIDs.contains(3) }?.region == .benefit)
    }

    @Test func `ineffective earlier operation yields to a later result and a hit takes priority over support`() throws {
        let empty = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .effect(.shieldApplied), amount: 0, keyword: .block, actionID: 1, authoredCardOperation: 0,
        )
        let block = BattleSessionTestSupport.makeActionEvent(
            id: 2, kind: .effect(.shieldApplied), amount: 5, keyword: .block, actionID: 1, authoredCardOperation: 1,
        )
        let hit = BattleSessionTestSupport.makeActionEvent(
            id: 3, kind: .abilityDamage, amount: 4, keyword: .physical, actionID: 1, authoredCardOperation: 2,
        )
        #expect(try #require(CombatFeedbackPresenter.makeItems(from: [empty, block], at: .now).first).region == .impact)
        let mixed = CombatFeedbackPresenter.makeItems(from: [empty, block, hit], at: .now)
        #expect(mixed.first { $0.id == 2 }?.region == .benefit)
        #expect(mixed.first { $0.id == 3 }?.region == .impact)
    }

    @Test func `health cost stays secondary when the card also deals damage`() {
        let cost = BattleSessionTestSupport.makeActionEvent(
            id: 1, kind: .abilityDamage, amount: 3, keyword: .physical, targetID: "hero", actionID: 1, authoredCardOperation: 0,
        )
        let hit = BattleSessionTestSupport.makeActionEvent(
            id: 2, kind: .abilityDamage, amount: 6, keyword: .physical, actionID: 1, authoredCardOperation: 1,
        )
        let items = CombatFeedbackPresenter.makeItems(from: [cost, hit], at: .now)
        #expect(items.first { $0.id == 1 }?.region == .setback)
        #expect(items.first { $0.id == 2 }?.region == .impact)
    }
}
