import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import BattleEngine
@testable import Trinket

struct CombatFeedbackPresenterTests {
    @Test func dropsZeroDamageAbilityChips() {
        let events = [
            makeEvent(id: 1, kind: .ability, amount: 0, keyword: .physical),
            makeEvent(id: 2, kind: .ability, amount: 5, keyword: .physical)
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 100))
        #expect(items.count == 1)
        #expect(items[0].id == 2)
        #expect(items[0].feedbackClass == .directDamage)
    }

    @Test func mergesCriticalIntoDamageChip() {
        let events = [
            makeEvent(id: 10, kind: .ability, amount: 12, keyword: .physical),
            makeEvent(
                id: 11,
                kind: .effect,
                effectKind: .criticalApplied,
                amount: 0,
                keyword: .physical
            )
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 100))
        #expect(items.count == 1)
        #expect(items[0].feedbackClass == .critical)
        #expect(items[0].text.contains("12"))
        #expect(items[0].secondaryText == "CRIT")
        #expect(items[0].reactionKind == .critical)
        #expect(items[0].sourceEventIDs == [10, 11])
    }

    @Test func classifiesStatusAsDotWithShorterLifetime() {
        let events = [
            makeEvent(id: 3, kind: .status, amount: 2, keyword: .burn)
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 50))
        #expect(items.count == 1)
        #expect(items[0].feedbackClass == .dot)
        #expect(items[0].lifetime == TrinketMotion.Battle.chip(for: .dot).lifetime)
        #expect(items[0].lifetime < TrinketMotion.Battle.chip(for: .directDamage).lifetime)
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
            )
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 1))
        #expect(items.map(\.feedbackClass) == [.heal, .dodge])
        #expect(items[0].reactionKind == .heal)
        #expect(items[1].reactionKind == .dodge)
    }

    @Test func actionGroupRowsShareAvailability() {
        let events = [
            makeEvent(id: 1, kind: .ability, amount: 3, keyword: .physical),
            makeEvent(id: 2, kind: .status, amount: 4, keyword: .bleed)
        ]
        let now = Date(timeIntervalSince1970: 1000)
        let items = CombatFeedbackPresenter.makeItems(
            from: events,
            at: now,
            stagger: 0.055
        )
        #expect(items[0].availableAt == now)
        #expect(items[1].availableAt == now)
        #expect(items.map(\.actionGroupID) == [1, 1])
    }

    @Test func staggerOffsetsDifferentTargetGroups() {
        let now = Date(timeIntervalSince1970: 1000)
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 3, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .ability,
                    amount: 4,
                    keyword: .physical,
                    targetID: "hero"
                )
            ],
            at: now,
            stagger: 0.055
        )
        #expect(items[0].availableAt == now)
        #expect(items[1].availableAt == now.addingTimeInterval(0.055))
    }

    @Test func sumsSameKeywordStatusEventsAndRetainsSourceIDs() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 2, keyword: .bleed)
            ],
            at: .now
        )
        #expect(items.count == 1)
        #expect(items[0].text == "-3 Bleed")
        #expect(items[0].sourceEventIDs == [1, 2])
    }

    @Test func sumsSameKeywordAbilityDamage() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .ability, amount: 4, keyword: .physical)
            ],
            at: .now
        )
        #expect(items.count == 1)
        #expect(items[0].text == "-6")
    }

    @Test func keepsSameKeywordEventsSeparateAcrossTargets() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(
                    id: 2,
                    kind: .status,
                    amount: 2,
                    keyword: .bleed,
                    targetID: "hero"
                )
            ],
            at: .now
        )
        #expect(items.count == 2)
        #expect(Set(items.map(\.targetID)) == ["enemy", "hero"])
    }

    @Test func keepsDirectAndStatusDamageSeparate() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 2, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 1, keyword: .bleed)
            ],
            at: .now
        )
        #expect(items.map(\.feedbackClass) == [.directDamage, .dot])
    }

    @Test func keepsDifferentAdditiveEffectKindsSeparate() {
        let items = CombatFeedbackPresenter.makeItems(
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
                )
            ],
            at: .now
        )
        #expect(items.count == 2)
        #expect(items.map(\.text) == ["+2 Health", "+3 Health"])
    }

    @Test func assignsPriorityAndOverflowMetadataDeterministically() {
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
                makeEvent(id: 5, kind: .ability, amount: 8, keyword: .physical)
            ],
            at: .now
        )
        #expect(items.count == 5)
        #expect(items[0].feedbackClass == .directDamage)
        #expect(items[0].presentationIndex == 0)
        #expect(items.allSatisfy { $0.groupResultCount == 5 })
        #expect(items.map(\.presentationIndex) == [0, 1, 2, 3, 4])
    }

    @Test func layoutJitterIsDeterministic() {
        let a = CombatFeedbackLayout.horizontalOffset(seed: 42, jitter: -10 ... 10)
        let b = CombatFeedbackLayout.horizontalOffset(seed: 42, jitter: -10 ... 10)
        let c = CombatFeedbackLayout.horizontalOffset(seed: 43, jitter: -10 ... 10)
        #expect(a == b)
        #expect(a != c)
        #expect((-10 ... 10).contains(a))
    }

    @Test func burstsSkipUtilityClasses() {
        let now = Date(timeIntervalSince1970: 10)
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 1,
                    kind: .effect,
                    effectKind: .dodgeApplied,
                    amount: 0,
                    keyword: .dodge
                ),
                makeEvent(id: 2, kind: .ability, amount: 5, keyword: .burn)
            ],
            at: now
        )
        let bursts = CombatFeedbackPresenter.bursts(for: items)
        #expect(bursts.count == 1)
        #expect(bursts[0].id == 2)
        #expect(bursts[0].particleCount == CombatFeedbackLayout.particleCount(for: .directDamage))
    }

    private func makeEvent(
        id: Int,
        kind: ActionEvent.Kind,
        effectKind: ActionEvent.EffectKind? = nil,
        amount: Int,
        keyword: Keyword,
        targetID: String = "enemy"
    ) -> ActionEvent {
        ActionEvent(
            id: id,
            kind: kind,
            effectKind: effectKind,
            actorID: "hero",
            actorName: "Hero",
            abilityID: "slash",
            abilityName: "Slash",
            targetID: targetID,
            targetName: targetID.capitalized,
            amount: amount,
            keyword: keyword
        )
    }
}
