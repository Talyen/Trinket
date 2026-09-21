import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

struct BattleFeedbackLaneTests {
    @Test(arguments: Keyword.damageTypes)
    @MainActor func `direct damage keywords always react`(keyword: Keyword) {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        lane.record([makeEvent(id: 1, kind: .abilityDamage, amount: 5, keyword: keyword)])
        #expect(lane.hitReactionsByTargetID["enemy"]?.kind == .damage)
    }

    @Test @MainActor func `block and critical damage cannot be hidden by other results`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        let blocked = ActionEvent(
            id: 1, actionID: 1, kind: .effect, effectKind: .shieldAbsorbed,
            actorName: "Hero", abilityName: "Slash", targetID: "enemy", targetName: "Enemy",
            amount: 5, keyword: .block, isFullyBlocked: true,
        )
        lane.record([blocked])
        #expect(lane.hitReactionsByTargetID["enemy"]?.kind == .block)
        lane.clear()
        lane.record([
            makeEvent(id: 2, kind: .effect, effectKind: .instantHeal, amount: 3, keyword: .health),
            makeEvent(id: 3, kind: .effect, effectKind: .dodgeApplied, amount: 0, keyword: .dodge),
            makeEvent(id: 4, kind: .abilityDamage, amount: 3, keyword: .burn),
            makeEvent(id: 5, kind: .abilityDamage, amount: 9, keyword: .holy, isCritical: true),
            makeEvent(id: 6, kind: .effect, effectKind: .thornsTriggered, amount: 2, keyword: .thorns, targetID: "hero"),
        ])
        #expect(lane.hitReactionsByTargetID["enemy"]?.kind == .critical)
        #expect(lane.hitReactionsByTargetID["hero"]?.kind == .damage)
    }

    @Test @MainActor func `periodic results stay quiet without suppressing matching direct damage`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        lane.record([makeEvent(id: 1, kind: .status, amount: 2, keyword: .burn)])
        #expect(lane.hitReactionsByTargetID.isEmpty)
        lane.clear()
        lane.record([
            makeEvent(id: 2, kind: .status, amount: 2, keyword: .burn),
            makeEvent(id: 3, kind: .abilityDamage, amount: 3, keyword: .burn),
        ])
        #expect(lane.hitReactionsByTargetID["enemy"]?.kind == .damage)
        #expect(lane.activeItems.first?.label == .amount(-5))
    }

    @Test @MainActor func `periodic critical emphasis does not upgrade an ordinary direct hit`() {
        let lane = BattleFeedbackLane()
        defer { lane.release() }
        lane.record([
            makeEvent(id: 1, kind: .status, amount: 5, keyword: .burn, isCritical: true),
            makeEvent(id: 2, kind: .abilityDamage, amount: 3, keyword: .burn),
        ], damage: [BattleResolvedDamage(
            targetID: "enemy", keyword: .burn, impact: .landed(blocked: 0, healthLost: 3), isCritical: false,
        )])
        #expect(lane.hitReactionsByTargetID["enemy"]?.kind == .damage)
        #expect(lane.activeItems.first?.isCritical == true)
    }

    /// Test-domain default: events share action 1 (one feedback group)
    /// unless a call site passes an explicit actionID. This intentionally
    /// differs from `BattleSessionTestSupport.makeActionEvent`, which
    /// defaults actionID to the event id.
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
                at: Date.now.addingTimeInterval(-CombatFeedbackMotionSampler.lifetime + 0.05),
            )
            #expect(try await BattleSessionTestSupport.waitUntil(timeout: .milliseconds(500)) {
                removedIDs.contains(id)
            })
            #expect(lane.activeItems.isEmpty)
            #expect(lane.hitReactionsByTargetID.isEmpty)
        }
        lane.record(
            [makeEvent(id: 3, kind: .abilityDamage, amount: 1, keyword: .physical)],
            at: Date.now.addingTimeInterval(-CombatFeedbackMotionSampler.lifetime + 0.05),
        )
        let cancelledDeadline = try #require(lane.nextPruneAt)
        lane.release()
        #expect(try await BattleSessionTestSupport.waitUntil {
            Date.now >= cancelledDeadline.addingTimeInterval(0.03)
        })
        #expect(removedIDs == [1, 2])
        #expect(lane.activeItems.isEmpty)
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
