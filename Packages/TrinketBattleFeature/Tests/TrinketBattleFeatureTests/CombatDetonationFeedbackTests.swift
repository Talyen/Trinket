import Foundation
import Testing
import TrinketCore
@testable import TrinketBattleFeature

struct CombatDetonationFeedbackTests {
    @Test @MainActor func `only the matching action detonation joins its hit and never a later burst`() throws {
        let start = Date.now.addingTimeInterval(10)
        let events = [
            BattleSessionTestSupport.makeActionEvent(
                id: 1, kind: .status, amount: 3, keyword: .burn, actionID: 1, damageActionID: 10, isDetonation: true,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 2, kind: .abilityDamage, amount: 5, keyword: .burn, isCritical: true,
                actionID: 1, authoredCardOperation: 0, damageActionID: 10,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 3, kind: .status, amount: 2, keyword: .burn, actionID: 1, origin: .periodic,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 4, kind: .status, amount: 4, keyword: .burn, actionID: 1, damageActionID: 11, isDetonation: true,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 5, kind: .status, amount: 1, keyword: .poison, actionID: 1, damageActionID: 10, isDetonation: true,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 6, kind: .status, amount: 7, keyword: .burn, targetID: "hero",
                actionID: 1, damageActionID: 10, isDetonation: true,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 7, kind: .abilityDamage, amount: 9, keyword: .burn,
                actionID: 1, reactionPayoff: .frostfire,
            ),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: start)
        let total = try #require(items.first { $0.sourceEventIDs.contains(2) })
        #expect(Set(total.sourceEventIDs) == [1, 2])
        #expect(total.label == .amount(-8))
        #expect(total.isCritical && total.isPrimaryCardResult && total.containsDetonation)
        #expect(items.count == 6)
        #expect(items.contains { $0.sourceEventIDs == [3] })
        #expect(items.contains { $0.sourceEventIDs == [4] })
        #expect(items.contains { $0.sourceEventIDs == [5] })
        #expect(items.contains { $0.sourceEventIDs == [6] })
        #expect(items.contains { $0.sourceEventIDs == [7] })

        let lane = BattleFeedbackLane()
        defer { lane.release() }
        lane.record(events, at: start)
        lane.record([
            BattleSessionTestSupport.makeActionEvent(
                id: 8, kind: .abilityDamage, amount: 6, keyword: .burn,
                actionID: 2, authoredCardOperation: 0, damageActionID: 12,
            ),
        ], at: start.addingTimeInterval(0.1))
        #expect(lane.activeItems.contains { Set($0.sourceEventIDs) == [1, 2] })
        #expect(lane.activeItems.contains { $0.sourceEventIDs == [8] })
    }
}
