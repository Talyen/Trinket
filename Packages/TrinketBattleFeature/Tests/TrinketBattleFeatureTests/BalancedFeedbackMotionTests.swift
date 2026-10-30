import BattleEngine
import CoreGraphics
import Foundation
import Testing
import TrinketCore
@testable import TrinketBattleFeature

struct BalancedFeedbackMotionTests {
    @Test @MainActor func `mixed rapid hits finish within two seconds and keep active paths`() throws {
        let lane = BattleFeedbackLane()
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
        #expect(try #require(lane.activeItems.map(\.expiresAt).max()).timeIntervalSince(start) < 2)
    }

    @Test @MainActor func `dense announcements retain every full animation instead of evicting older entries`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        for id in 1 ... 40 {
            lane.record(
                [BattleSessionTestSupport.makeActionEvent(id: id, kind: .reaction(.frostfire), amount: 0, keyword: .burn)],
                at: start,
            )
        }
        #expect(lane.activeItems.count == 40)
        #expect(lane.activeItems.allSatisfy { $0.availableAt.timeIntervalSince(start) <= 0.640001 })
        #expect(lane.activeItems.allSatisfy { abs($0.expiresAt.timeIntervalSince($0.availableAt) - 1.6) < 0.000001 })
    }

    @Test @MainActor func `repeated reactions keep order without delaying another recipient`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        for id in 1 ... 4 {
            lane.record(
                [BattleSessionTestSupport.makeActionEvent(id: id, kind: .reaction(.frostfire), amount: 0, keyword: .burn)],
                at: start,
            )
        }
        let first = try #require(lane.activeItems.first)
        lane.record([
            BattleSessionTestSupport.makeActionEvent(
                id: 5, kind: .reaction(.venomflash), amount: 0, keyword: .burn, targetID: "hero",
            ),
        ], at: start.addingTimeInterval(0.14))
        let enemy = lane.activeItems.filter { $0.targetID == first.targetID }
        #expect(enemy.map(\.id) == [1, 2, 3, 4])
        for (item, delay) in zip(enemy, [0.0, 0.32, 0.64, 0.64]) {
            #expect(abs(item.availableAt.timeIntervalSince(start) - delay) < 0.000001)
        }
        #expect(lane.activeItems.first == first)
        #expect(lane.activeItems.last?.availableAt == start.addingTimeInterval(0.14))
    }

    @Test @MainActor func `dense close impacts receive distinct routes without moving the first`() throws {
        let lane = BattleFeedbackLane()
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
        let lane = BattleFeedbackLane()
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
        #expect(numbers.allSatisfy { $0.availableAt == start })
    }

    @Test @MainActor func `reaction payoffs have separate bounded beats while health costs appear at impact`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([
            BattleSessionTestSupport.makeActionEvent(id: 1, kind: .reaction(.frostfire), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(
                id: 2, kind: .abilityDamage, amount: 2, keyword: .burn, actionID: 1, reactionPayoff: .frostfire,
            ),
            BattleSessionTestSupport.makeActionEvent(id: 3, kind: .reaction(.venomflash), amount: 0, keyword: .burn, actionID: 1),
            BattleSessionTestSupport.makeActionEvent(
                id: 4, kind: .abilityDamage, amount: 3, keyword: .burn, actionID: 1, reactionPayoff: .venomflash,
            ),
        ], at: start)
        let payoffs = lane.activeItems.filter {
            if case .reactionPayoff = $0.label {
                true
            } else {
                false
            }
        }
        try #require(payoffs.count == 2)
        #expect(payoffs[0].availableAt == start)
        #expect(abs(payoffs[1].availableAt.timeIntervalSince(start) - 0.32) < 0.000001)

        let first = BattleSessionTestSupport.makeActionEvent(
            id: 5, kind: .abilityDamage, amount: 4, keyword: .health, targetID: "hero", authoredCardOperation: 0,
        )
        let second = BattleSessionTestSupport.makeActionEvent(
            id: 6, kind: .abilityDamage, amount: 1000, keyword: .health, targetID: "hero", authoredCardOperation: 0,
        )
        lane.record([first], at: start)
        lane.record([second], at: start)
        let costs = lane.activeItems.filter(\.isCardHealthCost)
        #expect(costs.count == 2)
        #expect(costs.allSatisfy { $0.availableAt == start })
    }

    @Test @MainActor func `six close corner gains keep distinct stationary rows`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        let kinds: [ActionEvent.EffectOutcome] = [.shieldApplied, .thornsApplied, .leechApplied]
        let keywords: [Keyword] = [.block, .thorns, .leech]
        for index in 0 ..< 6 {
            lane.record([BattleSessionTestSupport.makeActionEvent(
                id: index + 1, kind: .effect(kinds[index % 3]), amount: 3, keyword: keywords[index % 3],
            )], at: start.addingTimeInterval(Double(index) * 0.14))
        }
        #expect(lane.activeItems.count == 6)
        #expect(Set(lane.activeItems.map(\.feedbackSpread)).count == 6)
    }
}
