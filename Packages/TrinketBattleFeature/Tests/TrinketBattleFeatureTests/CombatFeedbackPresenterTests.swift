import Foundation
import Testing
import BattleEngine
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
                makeEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .physical, actionID: 1),
                makeEvent(id: 2, kind: .abilityDamage, amount: 4, keyword: .physical, actionID: 1),
            ],
            at: .now
        )
        #expect(abilityItems.count == 1)
        #expect(abilityItems[0].text == "6")
        #expect(abilityItems[0].visualRole == .keyword)

        let sameKind = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 20, kind: .status, amount: 2, keyword: .bleed, actionID: 20),
                makeEvent(id: 21, kind: .status, amount: 3, keyword: .bleed, actionID: 20),
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
                    keyword: .block,
                    actionID: 7
                ),
                makeEvent(
                    id: 8,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 3,
                    keyword: .block,
                    actionID: 7
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
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed, actionID: 1),
                makeEvent(
                    id: 2, kind: .effect, effectKind: .resourceGain, amount: 1, keyword: .gold, actionID: 1
                ),
                makeEvent(
                    id: 3, kind: .effect, effectKind: .instantHeal, amount: 2, keyword: .health, actionID: 1
                ),
                makeEvent(
                    id: 4, kind: .effect, effectKind: .controlApplied, amount: 1, keyword: .stun, actionID: 1
                ),
                makeEvent(id: 5, kind: .abilityDamage, amount: 8, keyword: .physical, actionID: 1),
                makeEvent(
                    id: 6, kind: .effect, effectKind: .shieldApplied, amount: 3, keyword: .block, actionID: 1
                ),
                makeEvent(
                    id: 7, kind: .effect, effectKind: .dodgeApplied, amount: 0, keyword: .dodge, actionID: 1
                ),
                makeEvent(
                    id: 8, kind: .effect, effectKind: .resourceGain, amount: 2, keyword: .mana, actionID: 1
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
}

extension CombatFeedbackPresenterTests {
    @Test func keepsSameKindResultsSeparateAcrossActionIDs() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 4, keyword: .burn, actionID: 10),
                makeEvent(id: 2, kind: .abilityDamage, amount: 3, keyword: .burn, actionID: 11),
            ],
            at: .now
        )
        #expect(items.count == 2)
        #expect(items.map(\.actionGroupID) == [10, 11])
        #expect(items.map(\.text) == ["4", "3"])
        #expect(items.allSatisfy { $0.groupResultCount == 1 })
        #expect(items.allSatisfy { $0.presentationRole == .headline })
    }

    @Test func keepsPresentationRolesLocalToEachActionAndTarget() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .physical, actionID: 1),
                makeEvent(id: 2, kind: .status, amount: 1, keyword: .bleed, actionID: 1),
                makeEvent(
                    id: 3, kind: .effect, effectKind: .instantHeal, amount: 2, keyword: .health, actionID: 1
                ),
                makeEvent(
                    id: 4, kind: .effect, effectKind: .shieldApplied, amount: 3, keyword: .block, actionID: 1
                ),
                makeEvent(id: 5, kind: .abilityDamage, amount: 4, keyword: .physical, actionID: 2),
            ],
            at: .now
        )
        let firstAction = items.filter { $0.actionGroupID == 1 }
        let secondAction = items.filter { $0.actionGroupID == 2 }
        #expect(firstAction.count == 4)
        #expect(firstAction.allSatisfy { $0.groupResultCount == 4 })
        let firstHeadline = try #require(firstAction.first)
        #expect(firstHeadline.presentationRole == .headline)
        #expect(firstAction.dropFirst().allSatisfy { $0.presentationRole == .secondary })
        #expect(secondAction.count == 1)
        let secondItem = try #require(secondAction.first)
        #expect(secondItem.groupResultCount == 1)
        #expect(secondItem.presentationRole == .headline)
    }

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

    @Test func keepsAbilityDamageVisibleWhenEffectKindWouldHideAnEffectChip() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 1,
                    kind: .abilityDamage,
                    effectKind: .cardsDrawn,
                    amount: 6,
                    keyword: .physical
                ),
            ],
            at: .now
        )
        #expect(items.count == 1)
        #expect(items[0].feedbackClass == .directDamage)
        #expect(items[0].label == .amount(-6))
    }

    @Test func suppressesCardsControlBuildupLeechAppliedAndNumericZeroesButNamesZeroValueStatuses() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .effect, effectKind: .cardsDrawn, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .effect, effectKind: .controlApplied, amount: 4, keyword: .stun),
                makeEvent(id: 3, kind: .effect, effectKind: .shieldApplied, amount: 0, keyword: .block),
                makeEvent(id: 4, kind: .effect, effectKind: .nextHolyStrikeApplied, amount: 0, keyword: .holy),
                makeEvent(id: 5, kind: .effect, effectKind: .leechApplied, amount: 10, keyword: .physical),
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
        ].flatMap { CombatFeedbackPresenter.makeItems(from: [$0], at: now) }

        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        #expect(try #require(byID[4]).label == .word(.status(.thorns)))
        #expect(try #require(byID[6]).label == .word(.status(.criticalUp)))
        #expect(try #require(byID[7]).label == .word(.status(.marked)))
        #expect(try #require(byID[8]).label == .word(.status(.blockDown)))
    }

    @Test func mergesGoldGainsAndSuppressesGoldLossChips() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .effect, effectKind: .resourceGain, amount: 4, keyword: .gold, actionID: 1),
                makeEvent(id: 2, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .gold, actionID: 1),
                makeEvent(id: 3, kind: .effect, effectKind: .resourceGain, amount: -3, keyword: .gold, actionID: 1),
            ],
            at: .now
        )

        try #expect(items.count == 1)
        let gain = try #require(items.first)
        #expect(gain.label == .amount(7))
        #expect(gain.visualRole == .keyword)
    }
}
