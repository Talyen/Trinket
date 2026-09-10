import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

struct BattleFeedbackLaneTests {
    private func makeEvent(
        id: Int,
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectOutcome? = nil,
        amount: Int,
        keyword: Keyword,
        targetID: String = "enemy",
        isCritical: Bool = false,
        actionID: Int? = nil,
        abilityID: String = "slash",
        abilityName: String = "Slash",
    ) -> ActionEvent {
        BattleSessionTestSupport.makeActionEvent(
            id: id,
            kind: kind,
            effectKind: effectKind,
            amount: amount,
            keyword: keyword,
            targetID: targetID,
            isCritical: isCritical,
            actionID: actionID,
            abilityID: abilityID,
            abilityName: abilityName,
        )
    }

    @Test @MainActor func `successive feedback bursts expire automatically`() async throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        var removedIDs: Set<Int> = []
        lane.installBridge(ownerID: UUID()) { update in
            if case let .remove(ids) = update {
                removedIDs.formUnion(ids)
            }
        }
        for id in 1 ... 2 {
            lane.record(
                [makeEvent(id: id, kind: .abilityDamage, amount: 1, keyword: .physical)],
                at: Date.now.addingTimeInterval(-BattleMotion.chipDisplayDuration + 0.05),
            )
            #expect(try await BattleSessionTestSupport.waitUntil(timeout: .milliseconds(500)) {
                removedIDs.contains(id)
            })
            #expect(lane.activeItems.isEmpty)
            #expect(lane.hitReactionsByTargetID.isEmpty)
        }
        lane.record(
            [makeEvent(id: 3, kind: .abilityDamage, amount: 1, keyword: .physical)],
            at: Date.now.addingTimeInterval(-BattleMotion.chipDisplayDuration + 0.05),
        )
        let cancelledDeadline = try #require(lane.nextPruneAt)
        lane.release()
        #expect(try await BattleSessionTestSupport.waitUntil {
            Date.now >= cancelledDeadline.addingTimeInterval(0.03)
        })
        #expect(removedIDs == [1, 2])
        #expect(lane.activeItems.isEmpty)
    }

    @Test @MainActor func `expiry follows merged chips and celebration without clearing newer reactions`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date(timeIntervalSince1970: 1000)
        var removedIDs: Set<Int> = []
        lane.installBridge(ownerID: UUID()) { update in
            if case let .remove(ids) = update {
                removedIDs.formUnion(ids)
            }
        }
        lane.record([makeEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .physical)], at: start)
        let original = try #require(lane.activeItems.first)
        lane.record(
            [makeEvent(id: 2, kind: .abilityDamage, amount: 3, keyword: .physical)],
            at: start.addingTimeInterval(0.1),
        )
        let merged = try #require(lane.activeItems.first)
        #expect(merged.sourceEventIDs == [1, 2])
        #expect(merged.expiresAt > original.expiresAt)
        #expect(lane.nextPruneAt == merged.expiresAt.addingTimeInterval(0.02))

        lane.record(
            [makeEvent(id: 3, kind: .abilityDamage, amount: 4, keyword: .burn)],
            at: start.addingTimeInterval(0.2),
        )
        let newer = try #require(lane.activeItems.last)
        let celebrationExpiry = newer.expiresAt.addingTimeInterval(0.1)
        lane.hitReactionsByTargetID["hero"] = CombatantHitReaction(id: -1, kind: .celebrate)
        lane.celebrateReactionExpiresAt["hero"] = celebrationExpiry
        lane.updatePruneDate()
        #expect(lane.nextPruneAt == merged.expiresAt.addingTimeInterval(0.02))

        lane.pruneExpired(at: original.expiresAt)
        #expect(lane.activeItems.count == 2)
        lane.pruneExpired(at: merged.expiresAt)
        #expect(removedIDs == [merged.id])
        #expect(lane.activeItems.map(\.id) == [newer.id])
        #expect(lane.hitReactionsByTargetID["enemy"]?.id == newer.id)
        #expect(lane.nextPruneAt == newer.expiresAt.addingTimeInterval(0.02))

        lane.pruneExpired(at: newer.expiresAt)
        #expect(removedIDs == [merged.id, newer.id])
        #expect(lane.activeItems.isEmpty)
        #expect(lane.hitReactionsByTargetID["enemy"] == nil)
        #expect(lane.hitReactionsByTargetID["hero"]?.kind == .celebrate)
        #expect(lane.nextPruneAt == celebrationExpiry.addingTimeInterval(0.02))

        lane.pruneExpired(at: celebrationExpiry)
        #expect(lane.hitReactionsByTargetID.isEmpty)
        #expect(lane.celebrateReactionExpiresAt.isEmpty)
        #expect(lane.nextPruneAt == nil)
    }

    @Test @MainActor func `absorbs active on screen chips in place with lifetime reset`() {
        let lane = BattleFeedbackLane()
        let start = Date(timeIntervalSince1970: 1000)
        var updates: [CombatFeedbackUpdate] = []
        var playedSFX: [[String]] = []
        lane.installBridge(ownerID: UUID()) { updates.append($0) }
        let environment = BattleRuntimeDependencies(
            playSFX: { playedSFX.append($0) },
            warmSFX: { _, _ in },
            hapticsEnabled: { false },
            effectsVolume: { 1 },
            shouldAutoSkipUltimateCinematic: { _, _ in false },
        )
        let event1 = makeEvent(id: 1, kind: .abilityDamage, amount: 4, keyword: .burn)
        lane.record([event1], at: start, environment: environment)

        #expect(lane.activeItems.count == 1)
        #expect(lane.activeItems[0].text == "4")

        let nextTime = start.addingTimeInterval(0.2)
        let event2 = makeEvent(id: 2, kind: .abilityDamage, amount: 3, keyword: .burn)
        lane.record([event2], at: nextTime, environment: environment)

        #expect(lane.activeItems.count == 1)
        #expect(lane.activeItems[0].text == "7")
        #expect(lane.activeItems[0].availableAt == nextTime)
        #expect(lane.activeItems[0].expiresAt == nextTime.addingTimeInterval(BattleMotion.chipDisplayDuration))
        #expect(playedSFX.count == 2)
        #expect(lane.hitReactionsByTargetID[event2.targetID]?.id == event2.id)
        #expect(updates.count == 2)
        if case let .update(items) = updates[1] {
            #expect(items.map(\.id) == [event1.id])
        } else {
            Issue.record("Expected an incremental feedback update")
        }
        let mergedExpiry = lane.activeItems[0].expiresAt
        lane.pruneExpired(at: mergedExpiry)
        #expect(lane.activeItems.isEmpty)
        #expect(lane.hitReactionsByTargetID.isEmpty)
        if case let .remove(ids) = updates.last {
            #expect(ids == [event1.id])
        } else {
            Issue.record("Expected merged chip removal")
        }
    }

    @Test @MainActor func `does not absorb A chip before it becomes available`() {
        let lane = BattleFeedbackLane()
        let start = Date(timeIntervalSince1970: 1000)
        lane.record(
            [
                makeEvent(id: 1, kind: .status, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .status, amount: 4, keyword: .burn),
            ],
            at: start,
        )
        let queuedBurn = lane.activeItems.first { $0.id == 2 }
        #expect(queuedBurn?.availableAt == start.addingTimeInterval(BattleMotion.feedbackStreamStagger))

        lane.record(
            [makeEvent(id: 3, kind: .status, amount: 3, keyword: .burn)],
            at: start.addingTimeInterval(0.01),
        )

        #expect(lane.activeItems.count(where: { $0.keyword == .burn }) == 2)
    }

    @Test @MainActor func `absorbs staggered chip within lifetime from first visibility`() throws {
        let lane = BattleFeedbackLane()
        let start = Date(timeIntervalSince1970: 1000)
        let target = "enemy"

        lane.record(
            (1 ... 10).map { eventID in
                makeEvent(
                    id: eventID,
                    kind: .abilityDamage,
                    amount: 1,
                    keyword: .burn,
                    targetID: target,
                    actionID: eventID,
                )
            },
            at: start,
        )

        let lastChip = try #require(lane.activeItems.last)
        let visibleAt = lastChip.availableAt
        let expectedDelay = 9 * BattleMotion.feedbackStreamStagger
        #expect(abs(visibleAt.timeIntervalSince(start) - expectedDelay) < 0.001)

        let mergeTime = visibleAt.addingTimeInterval(0.08)
        lane.record(
            [makeEvent(id: 11, kind: .abilityDamage, amount: 2, keyword: .burn, targetID: target, actionID: 11)],
            at: mergeTime,
        )

        #expect(lane.activeItems.count == 10)
        #expect(lastChip.id == lane.activeItems.last?.id)
        #expect(lane.activeItems.last?.text == "3")
    }
}
