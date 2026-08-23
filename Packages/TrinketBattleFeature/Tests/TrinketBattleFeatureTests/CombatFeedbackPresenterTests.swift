import Foundation
import Testing
import TrinketBattleRuntime
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
@testable import BattleEngine
@testable import TrinketBattleFeature

struct CombatFeedbackPresenterTests {
    @Test func filtersMergesAndSumsDamageChips() {
        let filtered = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 5, keyword: .physical),
                makeEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .physical),
                makeEvent(id: 3, kind: .abilityDamage, amount: 0, keyword: .physical),
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].id == 2)
        #expect(filtered[0].feedbackClass == .directDamage)

        let critical = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 10,
                    kind: .abilityDamage,
                    amount: 12,
                    keyword: .physical,
                    isCritical: true
                ),
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        #expect(critical.count == 1)
        #expect(critical[0].feedbackClass == .critical)
        #expect(critical[0].reactionKind == .critical)
        #expect(critical[0].sourceEventIDs == [10])

        let abilityItems = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .abilityDamage, amount: 4, keyword: .physical),
            ],
            at: .now
        )
        #expect(abilityItems.count == 1)
        #expect(abilityItems[0].text == "6")
        #expect(abilityItems[0].visualRole == .keyword)

        let sameKind = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 20, kind: .status, amount: 2, keyword: .bleed),
                makeEvent(id: 21, kind: .status, amount: 3, keyword: .bleed),
            ],
            at: .now
        )
        #expect(sameKind.count == 1)
        #expect(sameKind[0].label == .amount(-5))
        #expect(sameKind[0].sourceEventIDs == [20, 21])

        let distinctKinds = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 30, kind: .abilityDamage, amount: 8, keyword: .physical),
                makeEvent(id: 31, kind: .status, amount: 3, keyword: .burn),
            ],
            at: .now
        )
        #expect(distinctKinds.count == 2)
        #expect(Set(distinctKinds.map(\.feedbackClass)) == [.directDamage, .dot])
    }

    @Test func afflictedAuraNameEventsDoNotProduceChips() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .ability,
                    amount: 0,
                    keyword: .physical,
                    abilityName: "Intense Heat"
                ),
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        #expect(items.count == 1)
        #expect(items[0].id == 1)
        #expect(items[0].feedbackClass == .directDamage)
    }

    @Test func consolidatesMatchingShieldEffects() {
        let shields = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 7,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 2,
                    keyword: .block
                ),
                makeEvent(
                    id: 8,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 3,
                    keyword: .block
                ),
            ],
            at: .now
        )
        #expect(shields.count == 1)
        #expect(shields[0].text == "5")
    }

    @Test func keepsCriticalDamageSeparateFromNoncriticalDamageAndMarkedConsume() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 20,
                    kind: .abilityDamage,
                    amount: 12,
                    keyword: .physical,
                    isCritical: true
                ),
                makeEvent(
                    id: 21,
                    kind: .effect,
                    effectKind: .markedConsumed,
                    amount: 3,
                    keyword: .physical
                ),
                makeEvent(id: 22, kind: .abilityDamage, amount: 4, keyword: .physical),
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        let critical = items.first { $0.sourceEventIDs.contains(20) }
        let ability = items.first { $0.sourceEventIDs.contains(22) }
        let marked = items.first { $0.sourceEventIDs.contains(21) }
        #expect(critical?.feedbackClass == .critical)
        #expect(critical?.sourceEventIDs == [20])
        #expect(ability?.feedbackClass == .directDamage)
        #expect(ability?.sourceEventIDs == [22])
        #expect(marked?.feedbackClass == .directDamage)
        #expect(marked?.sourceEventIDs == [21])
    }

    @Test func classifiesHealAndDodge() {
        let events = [
            makeEvent(
                id: 4,
                kind: .effect,
                effectKind: .instantHeal,
                amount: 8,
                keyword: .health
            ),
            makeEvent(
                id: 5,
                kind: .effect,
                effectKind: .dodgeApplied,
                amount: 0,
                keyword: .dodge
            ),
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 1))
        #expect(items.map(\.feedbackClass) == [.heal, .dodge])
        #expect(items[0].reactionKind == .heal)
        #expect(items[1].reactionKind == .dodge)
        #expect(items.count == 2)
        #expect(items[1].label == .word(.dodge))
    }

    @Test func presenterLeavesVisualQueueTimingToBattleSession() {
        let now = Date(timeIntervalSince1970: 1000)
        let sharedGroup = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical),
                makeEvent(id: 2, kind: .status, amount: 4, keyword: .bleed, actionID: 1),
            ],
            at: now
        )
        #expect(sharedGroup[0].availableAt == now)
        #expect(sharedGroup[1].availableAt == now)
        #expect(sharedGroup.map(\.actionGroupID) == [1, 1])

        let acrossTargets = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .abilityDamage,
                    amount: 4,
                    keyword: .physical,
                    targetID: "hero"
                ),
            ],
            at: now
        )
        #expect(acrossTargets[0].availableAt == now)
        #expect(acrossTargets[1].availableAt == now)
    }

    @Test func keepsDistinctFeedbackSeparateAcrossTargetsKindsAndDamageClasses() {
        let acrossTargets = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(
                    id: 2,
                    kind: .status,
                    amount: 2,
                    keyword: .bleed,
                    targetID: "hero"
                ),
            ],
            at: .now
        )
        #expect(acrossTargets.count == 2)
        #expect(Set(acrossTargets.map(\.targetID)) == ["enemy", "hero"])

        let acrossKinds = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 1,
                    kind: .effect,
                    effectKind: .instantHeal,
                    amount: 2,
                    keyword: .health
                ),
                makeEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .leechHeal,
                    amount: 3,
                    keyword: .health
                ),
            ],
            at: .now
        )
        #expect(acrossKinds.count == 2)
        #expect(acrossKinds.map(\.text) == ["2", "3"])

        let directAndStatus = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 1, keyword: .bleed),
            ],
            at: .now
        )
        #expect(directAndStatus.map(\.feedbackClass) == [.directDamage, .dot])
    }

    @Test func assignsPriorityAndPresentationRolesDeterministically() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: 1,
                    keyword: .gold
                ),
                makeEvent(
                    id: 3,
                    kind: .effect,
                    effectKind: .instantHeal,
                    amount: 2,
                    keyword: .health
                ),
                makeEvent(
                    id: 4,
                    kind: .effect,
                    effectKind: .controlApplied,
                    amount: 1,
                    keyword: .stun
                ),
                makeEvent(id: 5, kind: .abilityDamage, amount: 8, keyword: .physical),
                makeEvent(
                    id: 6,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 3,
                    keyword: .block
                ),
                makeEvent(
                    id: 7,
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    amount: 0,
                    keyword: .dodge
                ),
                makeEvent(
                    id: 8,
                    kind: .effect,
                    effectKind: .resourceGain,
                    amount: 2,
                    keyword: .mana
                ),
            ],
            at: .now
        )
        #expect(items.count == 7)
        #expect(items[0].feedbackClass == .directDamage)
        #expect(items[0].presentationIndex == 0)
        #expect(items.allSatisfy { $0.groupResultCount == 7 })
        #expect(items.map(\.presentationIndex) == Array(0 ..< 7))
        #expect(items[0].presentationRole == .headline)
        #expect(items.dropFirst().allSatisfy { $0.presentationRole == .secondary })
    }

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
        ActionEvent(
            id: id,
            actionID: actionID ?? id,
            kind: kind,
            effectKind: effectKind,
            actorID: "hero",
            actorName: "Hero",
            abilityID: abilityID,
            abilityName: abilityName,
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword,
            isCritical: isCritical
        )
    }
}

extension CombatFeedbackPresenterTests {
    @Test func overlayKeepsAllGroupsAndEmitsOneCanvasChipPerDistinctKind() {
        let first = CombatFeedbackPresenter.makeItems(
            from: [makeEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical)],
            at: Date(timeIntervalSince1970: 10)
        )
        let second = CombatFeedbackPresenter.makeItems(
            from: [makeEvent(id: 2, kind: .abilityDamage, amount: 4, keyword: .burn)],
            at: Date(timeIntervalSince1970: 10.65)
        )

        let chips = CombatFeedbackOverlayPolicy.orderedChips(from: first + second)

        #expect(chips.map(\.id) == [1, 2])

        let mixed = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 7, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 4,
                    keyword: .block
                ),
            ],
            at: Date(timeIntervalSince1970: 10)
        )
        let mixedChips = CombatFeedbackOverlayPolicy.orderedChips(from: mixed)

        #expect(mixedChips.count == 2)
        #expect(mixedChips.map(\.label) == [
            .amount(-7),
            .amount(4),
        ])
        #expect(mixedChips.map(\.feedbackClass) == [.directDamage, .buff])
        #expect(mixedChips.allSatisfy { !$0.label.displayString.contains("Effect") })
    }

    @Test func suppressesCardsControlBuildupAndNumericZeroesButNamesZeroValueStatuses() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .effect, effectKind: .cardsDrawn, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .effect, effectKind: .controlApplied, amount: 4, keyword: .stun),
                makeEvent(id: 3, kind: .effect, effectKind: .shieldApplied, amount: 0, keyword: .block),
                makeEvent(id: 4, kind: .effect, effectKind: .nextHolyStrikeApplied, amount: 0, keyword: .holy),
            ],
            at: .now
        )

        #expect(items.count == 1)
        #expect(items[0].label == .word(.status(.nextHolyStrike)))
        #expect(items[0].visualRole == .beneficialStatus)
    }

    @Test @MainActor func routesResourceAndNamedStatusVisuals() throws {
        let now = Date.now
        let items = [
            makeEvent(id: 1, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .gold),
            makeEvent(id: 2, kind: .effect, effectKind: .resourceGain, amount: 2, keyword: .mana),
            makeEvent(id: 3, kind: .effect, effectKind: .manaShieldTriggered, amount: 1, keyword: .mana),
            makeEvent(id: 4, kind: .effect, effectKind: .thornsApplied, amount: 2, keyword: .physical),
            makeEvent(id: 6, kind: .effect, effectKind: .criticalChanceApplied, amount: 15, keyword: .physical),
            makeEvent(id: 7, kind: .effect, effectKind: .markedApplied, amount: 3, keyword: .physical),
            makeEvent(id: 8, kind: .effect, effectKind: .shieldHalved, amount: 0, keyword: .block),
            makeEvent(id: 9, kind: .effect, effectKind: .leechApplied, amount: 10, keyword: .physical),
        ].flatMap { CombatFeedbackPresenter.makeItems(from: [$0], at: now) }

        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        #expect(try #require(byID[4]).label == .word(.status(.thorns)))
        #expect(try #require(byID[6]).label == .word(.status(.criticalUp)))
        #expect(try #require(byID[7]).label == .word(.status(.marked)))
        #expect(try #require(byID[8]).label == .word(.status(.blockDown)))

        let leech = try #require(byID[9])
        #expect(leech.label == .word(.status(.leech)))
        #expect(leech.visualRole == .beneficialStatus)
    }

    @Test func mergesGoldGainsAndSuppressesGoldLossChips() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .effect, effectKind: .resourceGain, amount: 4, keyword: .gold),
                makeEvent(id: 2, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .gold),
                makeEvent(id: 3, kind: .effect, effectKind: .resourceGain, amount: -3, keyword: .gold),
            ],
            at: .now
        )

        try #expect(items.count == 1)
        let gain = try #require(items.first)
        #expect(gain.label == .amount(7))
        #expect(gain.visualRole == .keyword)
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
}
