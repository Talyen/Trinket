import BattleEngine
import Foundation
import Testing
import TrinketCore
@testable import TrinketBattleFeature

struct CombatFeedbackBurstTests {
    @Test(arguments: [Keyword.freeze, .stun])
    @MainActor func `only genuine control activations notify including a second activation while visible`(keyword: Keyword) {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([
            event(1, .controlApplied, keyword: keyword),
            event(2, .controlTriggered, keyword: keyword),
            event(3, .controlActionSkipped, keyword: keyword),
            event(4, .controlActionSkipped, keyword: keyword),
        ], at: start)
        #expect(lane.activeItems.map(\.sourceEventIDs) == [[2]])
        #expect(lane.activeItems.first?.chipPresentation.text == (keyword == .freeze ? "Frozen" : "Stunned"))
        lane.record([event(5, .controlTriggered, keyword: keyword)], at: start.addingTimeInterval(0.1))
        #expect(lane.activeItems.map(\.sourceEventIDs) == [[2], [5]])
        lane.record([event(6, .controlActionSkipped, keyword: .bleed)], at: start.addingTimeInterval(0.2))
        #expect(lane.activeItems.contains { $0.sourceEventIDs == [6] })
        #expect(lane.activeItems.last?.chipPresentation.text == nil)
    }

    @Test @MainActor func `preparation refresh replaces its amount and numeric corner gains update quietly`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        lane.record([
            event(1, .physicalPreparationApplied, amount: 3, keyword: .physical),
            event(2, .resourceGain, amount: 2, keyword: .mana),
        ], at: start)
        let before = lane.activeItems
        let updateAt = start.addingTimeInterval(0.2)
        lane.record([
            event(3, .physicalPreparationApplied, amount: 7, keyword: .physical),
            event(4, .resourceGain, amount: 4, keyword: .mana),
        ], at: updateAt)
        #expect(lane.activeItems.count == 2)
        #expect(lane.activeItems.map(\.label) == [.amount(7, additive: false), .amount(6)])
        #expect(lane.activeItems.map(\.sourceEventIDs) == [[1, 3], [2, 4]])
        for (original, updated) in zip(before, lane.activeItems) {
            #expect(original.expiresAt == updated.expiresAt)
            #expect(CombatFeedbackMotionSampler.state(for: original, at: updateAt) == CombatFeedbackMotionSampler.state(
                for: updated,
                at: updateAt,
            ))
        }
        lane.record([event(5, .physicalPreparationApplied, amount: 100, keyword: .physical)], at: start.addingTimeInterval(0.3))
        let preparations = visible(lane).filter { $0.effectKind == .physicalPreparationApplied }
        #expect(preparations.count == 1)
        #expect(try #require(preparations.first).label == .amount(100, additive: false))
    }

    @Test @MainActor func `matching appearance cannot merge unrelated effect outcomes`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        lane.record([
            event(1, .resourceGain, amount: 3, keyword: .mana),
            event(2, .manaShieldTriggered, amount: 4, keyword: .mana),
        ])
        #expect(lane.activeItems.map(\.label) == [.amount(3), .amount(4)])
    }

    @Test @MainActor func `batch limits protect transitions and keep each corner and target independent`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        var publications: [[Int]] = []
        lane.installBridge(ownerID: UUID()) { update in
            if case let .replace(items) = update {
                publications.append(items.map(\.id))
            }
        }
        lane.record([
            event(1, .controlTriggered, keyword: .freeze),
            event(2, .deathsDoorTriggered, keyword: .deathsDoor),
            event(3, .markedApplied, keyword: .physical),
            event(4, .recurringDamageApplied, keyword: .poison),
            event(5, .wardApplied, keyword: .holy),
            event(6, .thornsApplied, keyword: .thorns),
            event(7, .resourceGain, keyword: .mana),
            event(8, .markedApplied, keyword: .physical, targetID: "hero"),
            event(9, .recurringDamageApplied, keyword: .poison, targetID: "hero"),
            event(10, .shieldAbsorbed, amount: 5, keyword: .block),
        ], at: start)
        let visibleIDs = Set(visible(lane).map(\.id))
        #expect(visibleIDs == [1, 2, 6, 7, 8, 9, 10])
        #expect(publications.count == 1 && Set(publications[0]) == visibleIDs)
        lane.noteItemsChanged()
        #expect(Set(publications.last ?? []) == visibleIDs)
        lane.setSuspended(true, at: start.addingTimeInterval(0.1))
        lane.setSuspended(false, at: start.addingTimeInterval(10.1))
        #expect(Set(visible(lane).map(\.id)) == visibleIDs)
        lane.pruneExpired(at: start.addingTimeInterval(12))
        #expect(lane.activeItems.isEmpty && lane.evictedItemIDs.isEmpty)
    }

    @Test @MainActor func `central damage remains uncapped and still combines compatible hits`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date.now.addingTimeInterval(10)
        let keywords: [Keyword] = [.physical, .burn, .freeze, .poison]
        lane.record(keywords.enumerated().map { index, keyword in
            BattleSessionTestSupport.makeActionEvent(id: index + 1, kind: .abilityDamage, amount: 3, keyword: keyword)
        }, at: start)
        lane.record(
            [BattleSessionTestSupport.makeActionEvent(id: 5, kind: .abilityDamage, amount: 4, keyword: .physical)],
            at: start.addingTimeInterval(0.1),
        )
        #expect(visible(lane).count == 4)
        #expect(lane.activeItems.first?.label == .amount(-7))
        #expect(lane.activeItems.first?.lastUpdatedAt != nil)
    }

    @MainActor private func visible(_ lane: BattleFeedbackLane) -> [CombatFeedbackItem] {
        lane.activeItems.filter { !lane.evictedItemIDs.contains($0.id) }
    }

    private func event(
        _ id: Int, _ outcome: ActionEvent.EffectOutcome, amount: Int = 1,
        keyword: Keyword, targetID: String = "enemy",
    ) -> ActionEvent {
        ActionEvent(
            id: id, actionID: id, kind: .effect, effectKind: outcome,
            actorName: "Hero", abilityName: "Feedback", targetID: targetID, targetName: targetID,
            amount: amount, keyword: keyword, isFullyBlocked: outcome == .shieldAbsorbed,
        )
    }
}
