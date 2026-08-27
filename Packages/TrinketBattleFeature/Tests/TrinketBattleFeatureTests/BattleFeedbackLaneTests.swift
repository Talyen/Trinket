import Foundation
import Testing
import BattleEngine
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
        abilityName: String = "Slash"
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
            abilityName: abilityName
        )
    }

    @Test @MainActor func absorbsActiveOnScreenChipsInPlaceWithLifetimeReset() {
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
            shouldAutoSkipUltimateCinematic: { _, _ in false }
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
        #expect(lane.activeItems[0].expiresAt == nextTime.addingTimeInterval(TrinketMotion.Battle.chipDisplayDuration))
        #expect(playedSFX.count == 2)
        #expect(lane.hitReactionsByTargetID[event2.targetID]?.id == event2.id)
        #expect(updates.count == 2)
        if case let .update(items) = updates[1] {
            #expect(items.map(\.id) == [event1.id])
        } else {
            Issue.record("Expected an incremental feedback update")
        }
    }

    @Test @MainActor func doesNotAbsorbAChipBeforeItBecomesAvailable() {
        let lane = BattleFeedbackLane()
        let start = Date(timeIntervalSince1970: 1000)
        lane.record(
            [
                makeEvent(id: 1, kind: .status, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .status, amount: 4, keyword: .burn),
            ],
            at: start
        )
        let queuedBurn = lane.activeItems.first { $0.id == 2 }
        #expect(queuedBurn?.availableAt == start.addingTimeInterval(TrinketMotion.Battle.feedbackStreamStagger))

        lane.record(
            [makeEvent(id: 3, kind: .status, amount: 3, keyword: .burn)],
            at: start.addingTimeInterval(0.01)
        )

        #expect(lane.activeItems.count(where: { $0.keyword == .burn }) == 2)
    }

    @Test @MainActor func absorbsStaggeredChipWithinLifetimeFromFirstVisibility() throws {
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
                    actionID: eventID
                )
            },
            at: start
        )

        let lastChip = try #require(lane.activeItems.last)
        let visibleAt = lastChip.availableAt
        let expectedDelay = 9 * TrinketMotion.Battle.feedbackStreamStagger
        #expect(abs(visibleAt.timeIntervalSince(start) - expectedDelay) < 0.001)

        let mergeTime = visibleAt.addingTimeInterval(0.08)
        lane.record(
            [makeEvent(id: 11, kind: .abilityDamage, amount: 2, keyword: .burn, targetID: target, actionID: 11)],
            at: mergeTime
        )

        #expect(lane.activeItems.count == 10)
        #expect(lastChip.id == lane.activeItems.last?.id)
        #expect(lane.activeItems.last?.text == "3")
    }
}
