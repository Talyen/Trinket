import BattleEngine
import CoreGraphics
import Foundation
import Testing
import TrinketCore
@testable import TrinketBattleFeature

struct BalancedFeedbackMotionTests {
    @Test @MainActor func `mixed rapid hits finish within two seconds and keep active paths`() throws {
        let lane = BattleFeedbackLane()
        lane.usesBalancedFeedback = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        for index in 0 ..< 6 {
            let date = start.addingTimeInterval(Double(index) * 0.14)
            let before = lane.activeItems
            lane.record([
                BattleSessionTestSupport.makeActionEvent(
                    id: index * 3 + 1,
                    kind: .abilityDamage,
                    amount: 7,
                    keyword: index.isMultiple(of: 2) ? .physical : .burn,
                ),
                BattleSessionTestSupport.makeActionEvent(id: index * 3 + 2, kind: .effect(.instantHeal), amount: 4, keyword: .health),
                BattleSessionTestSupport.makeActionEvent(
                    id: index * 3 + 3,
                    kind: .effect(.shieldAbsorbed),
                    amount: 3,
                    keyword: .block,
                    isFullyBlocked: true,
                ),
            ], at: date)
            for old in before where old.availableAt <= date {
                let retained = try #require(lane.activeItems.first { $0.id == old.id })
                #expect(retained.availableAt == old.availableAt)
                #expect(retained.expiresAt == old.expiresAt)
                #expect(retained.feedbackSpread == old.feedbackSpread)
            }
            for item in lane.activeItems where !before.contains(where: { $0.id == item.id }) {
                #expect(item.availableAt.timeIntervalSince(date) <= 0.180001)
                #expect(abs(item.expiresAt.timeIntervalSince(item.availableAt) - 1.05) < 0.000001)
            }
        }
        #expect(lane.activeItems.contains { $0.feedbackClass == .block })
        #expect(lane.evictedItemIDs.isEmpty)
        #expect(try #require(lane.activeItems.map(\.expiresAt).max()).timeIntervalSince(start) < 2)
    }

    @Test @MainActor func `dense announcements retain every full animation instead of evicting older entries`() {
        let lane = BattleFeedbackLane()
        lane.usesBalancedFeedback = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        for id in 1 ... 40 {
            lane.record(
                [BattleSessionTestSupport.makeActionEvent(id: id, kind: .reaction(.frostfire), amount: 0, keyword: .burn)],
                at: start,
            )
        }
        #expect(lane.activeItems.count == 40)
        #expect(lane.evictedItemIDs.isEmpty)
        #expect(lane.activeItems.allSatisfy { $0.availableAt.timeIntervalSince(start) <= 0.180001 })
        #expect(lane.activeItems.allSatisfy { abs($0.expiresAt.timeIntervalSince($0.availableAt) - 1.6) < 0.000001 })
    }

    @Test @MainActor func `dense close impacts receive distinct routes without moving the first`() throws {
        let lane = BattleFeedbackLane()
        lane.usesBalancedFeedback = true
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        let keywords: [Keyword] = [.physical, .burn, .freeze, .poison]
        lane.record([BattleSessionTestSupport.makeActionEvent(id: 1, kind: .abilityDamage, amount: 7, keyword: .physical)], at: start)
        let first = try #require(lane.activeItems.first)
        for index in 1 ..< 4 {
            lane.record(
                [BattleSessionTestSupport.makeActionEvent(id: index + 1, kind: .abilityDamage, amount: 8, keyword: keywords[index])],
                at: start.addingTimeInterval(Double(index) * 0.04),
            )
        }
        #expect(lane.activeItems.first == first)
        #expect(Set(lane.activeItems.map(\.feedbackSpread)).count >= 3)
    }

    @Test @MainActor func `reaction damage types cannot share an identical simultaneous path`() {
        let lane = BattleFeedbackLane(balanced: true)
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .reaction(.frostfire), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(id: 2, kind: .abilityDamage, amount: 12, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .abilityDamage, amount: 8, keyword: .freeze, actionID: 1),
        ], at: start)
        let numbers = lane.activeItems.filter { $0.region == .impact }
        #expect(numbers.count == 2)
        #expect(Set(numbers.map(\.feedbackSpread)).count == 2)
        #expect(numbers.allSatisfy { $0.availableAt.timeIntervalSince(start) <= 0.180001 })
    }
}
