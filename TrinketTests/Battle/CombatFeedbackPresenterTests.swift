import Foundation
import Testing
import TrinketCore
import TrinketDesignSystem
@testable import BattleEngine
@testable import Trinket

struct CombatFeedbackPresenterTests {
    @Test func filtersMergesAndSumsDamageChips() {
        let filtered = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 0, keyword: .physical),
                makeEvent(id: 2, kind: .ability, amount: 5, keyword: .physical)
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        #expect(filtered.count == 1)
        #expect(filtered[0].id == 2)
        #expect(filtered[0].feedbackClass == .directDamage)

        let merged = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 10, kind: .ability, amount: 12, keyword: .physical),
                makeEvent(
                    id: 11,
                    kind: .effect,
                    effectKind: .criticalApplied,
                    amount: 0,
                    keyword: .physical
                )
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        #expect(merged.count == 1)
        #expect(merged[0].feedbackClass == .critical)
        #expect(merged[0].text.contains("12"))
        #expect(merged[0].secondaryText == nil)
        #expect(merged[0].reactionKind == .critical)
        #expect(merged[0].sourceEventIDs == [10, 11])

        let statusItems = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 2, keyword: .bleed)
            ],
            at: .now
        )
        #expect(statusItems.count == 1)
        #expect(statusItems[0].text == "-3")
        #expect(statusItems[0].sourceEventIDs == [1, 2])

        let abilityItems = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .ability, amount: 4, keyword: .physical)
            ],
            at: .now
        )
        #expect(abilityItems.count == 1)
        #expect(abilityItems[0].text == "-6")
    }

    @Test func prefersAbilityChipOverMarkedConsumeWhenMergingCritical() {
        // Pipeline order: criticalApplied → markedConsumed → ability damage.
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 20,
                    kind: .effect,
                    effectKind: .criticalApplied,
                    amount: 0,
                    keyword: .physical
                ),
                makeEvent(
                    id: 21,
                    kind: .effect,
                    effectKind: .markedConsumed,
                    amount: 3,
                    keyword: .physical
                ),
                makeEvent(id: 22, kind: .ability, amount: 12, keyword: .physical)
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        let ability = items.first { $0.sourceEventIDs.contains(22) }
        let marked = items.first { $0.sourceEventIDs.contains(21) }
        #expect(ability?.feedbackClass == .critical)
        #expect(ability?.sourceEventIDs == [22, 20])
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
            )
        ]
        let items = CombatFeedbackPresenter.makeItems(from: events, at: Date(timeIntervalSince1970: 1))
        #expect(items.map(\.feedbackClass) == [.heal, .dodge])
        #expect(items[0].reactionKind == .heal)
        #expect(items[1].reactionKind == .dodge)
        #expect(items[1].text == "Dodge")
    }

    @Test func actionGroupTimingSharesAvailabilityAndStaggersTargets() {
        let now = Date(timeIntervalSince1970: 1000)
        let sharedGroup = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 3, keyword: .physical),
                makeEvent(id: 2, kind: .status, amount: 4, keyword: .bleed)
            ],
            at: now,
            stagger: 0.055
        )
        #expect(sharedGroup[0].availableAt == now)
        #expect(sharedGroup[1].availableAt == now)
        #expect(sharedGroup.map(\.actionGroupID) == [1, 1])

        let staggered = CombatFeedbackPresenter.makeItems(
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
        #expect(staggered[0].availableAt == now)
        #expect(staggered[1].availableAt == now.addingTimeInterval(0.055))
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
                )
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
                )
            ],
            at: .now
        )
        #expect(acrossKinds.count == 2)
        #expect(acrossKinds.map(\.text) == ["+2", "+3"])

        let directAndStatus = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 2, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 1, keyword: .bleed)
            ],
            at: .now
        )
        #expect(directAndStatus.map(\.feedbackClass) == [.directDamage, .dot])
        #expect(directAndStatus[1].lifetime == TrinketMotion.Battle.chip(for: .dot).lifetime)
        #expect(directAndStatus[1].lifetime < TrinketMotion.Battle.chip(for: .directDamage).lifetime)
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

    @Test func overlayKeepsNewestGroupAndCondensesCanvasLabels() {
        let first = CombatFeedbackPresenter.makeItems(
            from: [makeEvent(id: 1, kind: .ability, amount: 3, keyword: .physical)],
            at: Date(timeIntervalSince1970: 10)
        )
        let second = CombatFeedbackPresenter.makeItems(
            from: [makeEvent(id: 2, kind: .ability, amount: 4, keyword: .burn)],
            at: Date(timeIntervalSince1970: 10.65)
        )

        let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: first + second)

        #expect(groups.count == CombatFeedbackOverlayPolicy.maxSimultaneousActionGroups)
        #expect(groups.first?.id == 2)
        #expect(groups.first?.items.map(\.id) == [2])

        let condensed = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .ability, amount: 7, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 4,
                    keyword: .block
                )
            ],
            at: Date(timeIntervalSince1970: 10)
        )
        let condensedGroups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: condensed)
        let canvasItems = CombatFeedbackOverlayPolicy.canvasItems(from: condensedGroups)

        #expect(canvasItems.count == 1)
        #expect(canvasItems.first?.text.contains("+1 Effect") == true)
    }

    @Test @MainActor func feedbackRasterPoolReusesAndBoundsPreparedLabels() throws {
        let pool = CombatFeedbackRasterPool(capacity: 2)
        let canvasItems = [3, 4, 5].map { amount in
            let items = CombatFeedbackPresenter.makeItems(
                from: [makeEvent(id: amount, kind: .ability, amount: amount, keyword: .physical)],
                at: Date(timeIntervalSince1970: 10)
            )
            return CombatFeedbackOverlayPolicy.canvasItems(
                from: CombatFeedbackOverlayPolicy.visibleActionGroups(from: items)
            )[0]
        }

        let first = try #require(pool.raster(
            for: canvasItems[0],
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        let reused = try #require(pool.raster(
            for: canvasItems[0],
            dynamicTypeSize: .large,
            displayScale: 2
        ))
        #expect(first === reused)

        _ = pool.raster(for: canvasItems[1], dynamicTypeSize: .large, displayScale: 2)
        _ = pool.raster(for: canvasItems[2], dynamicTypeSize: .large, displayScale: 2)
        let snapshot = pool.snapshot()
        #expect(snapshot.entryCount == 2)
        #expect(snapshot.estimatedByteCount > 0)
        #expect(snapshot.hitCount == 1)
        #expect(snapshot.buildCount == 3)
        #expect(snapshot.evictionCount == 1)
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
