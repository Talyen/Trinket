import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatReactionFeedbackTests {
    @Test func `reaction payoff stays paired with its name and separate from the original hit`() throws {
        let start = Date(timeIntervalSince1970: 10)
        let events = [
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .reaction(.frostfire), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(
                id: 3, kind: .abilityDamage, amount: 2, keyword: .burn, actionID: 1, reactionPayoff: .frostfire,
            ),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: start).map { $0.scheduled(at: start) }
        let announcement = try #require(items.first { $0.region == .announcement })
        let damage = try #require(items.first { $0.region == .impact })
        #expect(announcement.label == .reactionPayoff(.frostfire, 2))
        #expect(announcement.chipPresentation.reaction == .frostfire)
        #expect(announcement.expiresAt == start.addingTimeInterval(1.6))
        #expect(damage.label == .amount(-8))
        #expect(damage.sourceEventIDs == [1])
        #expect(announcement.sourceEventIDs == [2, 3])
        #expect(BalancedFeedbackMotion.state(for: announcement, at: start.addingTimeInterval(1.2)).opacity == 1)
        #expect(CombatSFXMapper.clipID(for: [events[1]]) == nil)
    }

    @Test func `distinct reactions keep their own typed payoffs`() {
        let events = [
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .reaction(.frostfire), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .reaction(.venomflash), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(
                id: 3, kind: .abilityDamage, amount: 2, keyword: .burn, actionID: 1, reactionPayoff: .frostfire,
            ),
            BattleSessionTestSupport.makeActionEvent(
                id: 4, kind: .abilityDamage, amount: 3, keyword: .burn, actionID: 1, reactionPayoff: .venomflash,
            ),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: .now)
        #expect(items.count == 2)
        #expect(items.contains { $0.label == .reactionPayoff(.frostfire, 2) && $0.sourceEventIDs == [1, 3] })
        #expect(items.contains { $0.label == .reactionPayoff(.venomflash, 3) && $0.sourceEventIDs == [2, 4] })
    }
}
