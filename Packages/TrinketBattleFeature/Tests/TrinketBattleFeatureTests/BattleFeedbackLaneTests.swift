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
            actionID: actionID ?? 1,
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

    @Test @MainActor func `merges matching queued and visible outcomes without restarting motion`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date(timeIntervalSince1970: 1000)
        lane.record([
            makeEvent(id: 1, kind: .abilityDamage, amount: 4, keyword: .burn),
            makeEvent(id: 2, kind: .status, amount: 2, keyword: .poison),
        ], at: start)
        #expect(lane.activeItems.allSatisfy { $0.availableAt == start })
        lane.activeItems[0].availableAt = start.addingTimeInterval(0.1)
        lane.record([makeEvent(id: 3, kind: .status, amount: 3, keyword: .burn)], at: start.addingTimeInterval(0.01))
        #expect(lane.activeItems.count == 2)
        #expect(lane.activeItems[0].label == .amount(-7))
        #expect(lane.activeItems[0].firstScheduledAt == start)
        lane.record(
            [makeEvent(id: 4, kind: .abilityDamage, amount: 5, keyword: .burn, isCritical: true)],
            at: start.addingTimeInterval(0.6),
        )
        let merged = try #require(lane.activeItems.first)
        #expect(merged.id == 1)
        #expect(merged.label == .amount(-12))
        #expect(merged.sourceEventIDs == [1, 3, 4])
        #expect(merged.firstScheduledAt == start)
        #expect(merged.isCritical)
        #expect(merged.criticalAt == start.addingTimeInterval(0.6))
        #expect(lane.activeItems.allSatisfy { $0.expiresAt == start.addingTimeInterval(1.2) })
        lane.pruneExpired(at: start.addingTimeInterval(1.2))
        #expect(lane.activeItems.isEmpty)
        #expect(lane.hitReactionsByTargetID.isEmpty)
    }

    @Test @MainActor func `rapid cards hand off immediately without merging or accumulating a queue`() throws {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date(timeIntervalSince1970: 1000)
        for id in 1 ... 10 {
            let date = start.addingTimeInterval(Double(id) * 0.01)
            lane.record([makeEvent(id: id, kind: .abilityDamage, amount: id, keyword: .burn, actionID: id)], at: date)
            #expect(lane.activeItems.count <= 2)
            let latest = try #require(lane.activeItems.last)
            #expect(latest.availableAt == date)
            #expect(latest.label == .amount(-id))
            #expect(latest.retiringAt == nil)
        }
        let older = try #require(lane.activeItems.first)
        #expect(older.retiringAt == start.addingTimeInterval(0.1))
        lane.pruneExpired(at: start.addingTimeInterval(0.26))
        #expect(lane.activeItems.map(\.id) == [10])
        #expect(lane.hitReactionsByTargetID["enemy"]?.id == 10)
    }

    @Test @MainActor func `repeated delivery does not replay sound and expiration preserves celebration`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let start = Date(timeIntervalSince1970: 1000)
        var sounds = 0
        let environment = BattleRuntimeDependencies(
            playSFX: { _ in sounds += 1 }, warmSFX: { _, _ in }, hapticsEnabled: { false },
            effectsVolume: { 1 }, shouldAutoSkipUltimateCinematic: { _, _ in false },
        )
        let event = makeEvent(id: 1, kind: .abilityDamage, amount: 4, keyword: .physical)
        lane.record([event], at: start, environment: environment)
        lane.record([event], at: start.addingTimeInterval(0.1), environment: environment)
        #expect(sounds == 1)
        #expect(lane.activeItems.first?.label == .amount(-4))
        lane.hitReactionsByTargetID["hero"] = CombatantHitReaction(id: -1, kind: .celebrate)
        lane.celebrateReactionExpiresAt["hero"] = start.addingTimeInterval(1.4)
        lane.pruneExpired(at: start.addingTimeInterval(1))
        #expect(lane.hitReactionsByTargetID["enemy"] == nil)
        #expect(lane.hitReactionsByTargetID["hero"]?.kind == .celebrate)
        lane.clear()
        #expect(lane.activeItems.isEmpty)
        #expect(lane.celebrateReactionExpiresAt.isEmpty)
        #expect(lane.nextPruneAt == nil)
    }
}
