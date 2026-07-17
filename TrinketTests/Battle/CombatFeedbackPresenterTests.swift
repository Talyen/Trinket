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
                makeEvent(id: 1, kind: .ability, amount: 5, keyword: .physical),
                makeEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .physical),
                makeEvent(id: 3, kind: .abilityDamage, amount: 0, keyword: .physical)
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
                )
            ],
            at: Date(timeIntervalSince1970: 100)
        )
        #expect(critical.count == 1)
        #expect(critical[0].feedbackClass == .critical)
        #expect(critical[0].text.contains("12"))
        #expect(critical[0].secondaryText == nil)
        #expect(critical[0].reactionKind == .critical)
        #expect(critical[0].sourceEventIDs == [10])

        let statusItems = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 1, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 2, keyword: .bleed)
            ],
            at: .now
        )
        #expect(statusItems.count == 1)
        #expect(statusItems[0].text == "3")
        #expect(statusItems[0].sourceEventIDs == [1, 2])

        let abilityItems = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .abilityDamage, amount: 4, keyword: .physical)
            ],
            at: .now
        )
        #expect(abilityItems.count == 1)
        #expect(abilityItems[0].text == "6")
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
                )
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
                makeEvent(id: 22, kind: .abilityDamage, amount: 4, keyword: .physical)
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
                makeEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical),
                makeEvent(id: 2, kind: .status, amount: 4, keyword: .bleed, actionID: 1)
            ],
            at: now,
            stagger: 0.055
        )
        #expect(sharedGroup[0].availableAt == now)
        #expect(sharedGroup[1].availableAt == now)
        #expect(sharedGroup.map(\.actionGroupID) == [1, 1])

        let staggered = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 3, keyword: .physical),
                makeEvent(
                    id: 2,
                    kind: .abilityDamage,
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
        #expect(acrossKinds.map(\.text) == ["2", "3"])

        let directAndStatus = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 2, keyword: .bleed),
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
                makeEvent(id: 5, kind: .abilityDamage, amount: 8, keyword: .physical)
            ],
            at: .now
        )
        #expect(items.count == 4)
        #expect(items[0].feedbackClass == .directDamage)
        #expect(items[0].presentationIndex == 0)
        #expect(items.allSatisfy { $0.groupResultCount == 4 })
        #expect(items.map(\.presentationIndex) == [0, 1, 2, 3])
    }

    @Test @MainActor func feedbackRasterPoolReusesAndBoundsPreparedLabels() throws {
        let pool = CombatFeedbackRasterPool(capacity: 2)
        let canvasItems = [3, 4, 5].map { amount in
            let items = CombatFeedbackPresenter.makeItems(
                from: [makeEvent(id: amount, kind: .abilityDamage, amount: amount, keyword: .physical)],
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
        let reused = try #require(pool.cachedRaster(
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
                makeEvent(id: 2, kind: .abilityDamage, amount: 5, keyword: .burn)
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

        let groups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: first + second)

        #expect(groups.map(\.id) == [1, 2])
        #expect(groups.flatMap(\.items).map(\.id) == [1, 2])

        let mixed = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 7, keyword: .physical),
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
        let mixedGroups = CombatFeedbackOverlayPolicy.visibleActionGroups(from: mixed)
        let canvasItems = CombatFeedbackOverlayPolicy.canvasItems(from: mixedGroups)

        #expect(canvasItems.count == 2)
        #expect(canvasItems.map(\.label) == [
            .amount(-7),
            .amount(4)
        ])
        #expect(canvasItems.map(\.item.feedbackClass) == [.directDamage, .buff])
        #expect(canvasItems.allSatisfy { !$0.text.contains("Effect") })
    }

    @Test func sameKindAmountsConsolidateWhileDistinctKindsStaySeparate() {
        let sameKind = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .status, amount: 2, keyword: .bleed),
                makeEvent(id: 2, kind: .status, amount: 3, keyword: .bleed)
            ],
            at: .now
        )
        #expect(sameKind.count == 1)
        #expect(sameKind[0].label == .amount(-5))
        #expect(sameKind[0].sourceEventIDs == [1, 2])

        let distinctKinds = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .abilityDamage, amount: 8, keyword: .physical),
                makeEvent(id: 2, kind: .status, amount: 3, keyword: .burn)
            ],
            at: .now
        )
        #expect(distinctKinds.count == 2)
        #expect(Set(distinctKinds.map(\.feedbackClass)) == [.directDamage, .dot])
    }

    @Test func chipLabelClassifiesAmountPercentAndWord() {
        #expect(CombatFeedbackChipLabel.fromDisplayText("-12") == .amount(-12))
        #expect(CombatFeedbackChipLabel.fromDisplayText("+8") == .amount(8))
        #expect(CombatFeedbackChipLabel.fromDisplayText("+25%") == .percent(25))
        #expect(CombatFeedbackChipLabel.fromDisplayText("-12")?.displayString == "12")
        #expect(CombatFeedbackChipLabel.fromDisplayText("+8")?.displayString == "8")
        #expect(CombatFeedbackChipLabel.fromDisplayText("+25%")?.displayString == "25%")
        #expect(CombatFeedbackChipLabel.fromDisplayText("Dodge") == .word(.dodge))
        #expect(CombatFeedbackChipLabel.fromDisplayText("Critical") == .word(.critical))
        #expect(CombatFeedbackChipLabel.fromDisplayText("Stunned!") == .word(.triggered(.stun)))
        #expect(CombatFeedbackChipLabel.fromDisplayText("+Block") == .word(.applied(.block)))
        #expect(CombatFeedbackChipLabel.fromDisplayText("+Block")?.displayString == "Block")
        #expect(CombatFeedbackChipLabel.fromDisplayText("Cleanse Bleeding") == .word(.cleanse(.bleed)))
        #expect(CombatFeedbackChipLabel.fromDisplayText("Purge Block") == .word(.purge(.block)))
        #expect(CombatFeedbackChipLabel.fromDisplayText("Halve Armor") == .word(.halve(.armor)))
        #expect(CombatFeedbackChipLabel.fromDisplayText("Death's Door") == .word(.plain(.deathsDoor)))
    }

    @Test func suppressesCardsControlBuildupAndNumericZeroesButNamesZeroValueStatuses() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .effect, effectKind: .cardsDrawn, amount: 2, keyword: .physical),
                makeEvent(id: 2, kind: .effect, effectKind: .controlApplied, amount: 4, keyword: .stun),
                makeEvent(id: 3, kind: .effect, effectKind: .shieldApplied, amount: 0, keyword: .block),
                makeEvent(id: 4, kind: .effect, effectKind: .nextHolyStrikeApplied, amount: 0, keyword: .holy)
            ],
            at: .now
        )

        #expect(items.count == 1)
        #expect(items[0].text == "Next Holy Strike")
        #expect(items[0].visualRole == .beneficialStatus)
    }

    @Test @MainActor func routesResourceAndNamedStatusVisuals() throws {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(id: 1, kind: .effect, effectKind: .resourceGain, amount: 3, keyword: .gold),
                makeEvent(id: 2, kind: .effect, effectKind: .resourceGain, amount: 2, keyword: .mana),
                makeEvent(id: 3, kind: .effect, effectKind: .manaShieldTriggered, amount: 1, keyword: .mana),
                makeEvent(id: 4, kind: .effect, effectKind: .thornsApplied, amount: 2, keyword: .physical),
                makeEvent(id: 5, kind: .effect, effectKind: .hasteApplied, amount: 2, keyword: .physical),
                makeEvent(id: 6, kind: .effect, effectKind: .criticalChanceApplied, amount: 15, keyword: .physical),
                makeEvent(id: 7, kind: .effect, effectKind: .markedApplied, amount: 3, keyword: .physical),
                makeEvent(id: 8, kind: .effect, effectKind: .mitigationHalved, amount: 0, keyword: .armor)
            ],
            at: .now
        )

        let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        #expect(try #require(byID[1]).feedbackVisualStyle.symbolName == "circle.circle.fill")
        #expect(try #require(byID[2]).feedbackVisualStyle.symbolName == "moon.stars.fill")
        #expect(try #require(byID[3]).feedbackVisualStyle.symbolName == "moon.stars.fill")
        #expect(try #require(byID[4]).text == "Thorns")
        #expect(try #require(byID[5]).text == "Hasted")
        #expect(try #require(byID[6]).text == "Critical Up")
        #expect(try #require(byID[7]).text == "Marked")
        #expect(try #require(byID[7]).feedbackVisualStyle.symbolName == "arrowshape.down.fill")
        #expect(try #require(byID[8]).text == "Armor Down")
        #expect(try #require(byID[8]).feedbackVisualStyle.symbolName == "arrowshape.down.fill")
        #expect(try #require(byID[4]).feedbackVisualStyle.symbolName == "arrowshape.up.fill")
    }

    @Test func avatarOfJusticeConsolidatesItsEffectChips() {
        let items = CombatFeedbackPresenter.makeItems(
            from: [
                makeEvent(
                    id: 10,
                    kind: .effect,
                    effectKind: .shieldApplied,
                    amount: 5,
                    keyword: .block,
                    actionID: 99,
                    abilityID: "avatar-of-justice",
                    abilityName: "Avatar of Justice"
                ),
                makeEvent(
                    id: 11,
                    kind: .effect,
                    effectKind: .mitigationApplied,
                    amount: 2,
                    keyword: .armor,
                    actionID: 99,
                    abilityID: "avatar-of-justice",
                    abilityName: "Avatar of Justice"
                ),
                makeEvent(
                    id: 12,
                    kind: .effect,
                    effectKind: .damageKeywordOverrideApplied,
                    amount: 3,
                    keyword: .holy,
                    actionID: 99,
                    abilityID: "avatar-of-justice",
                    abilityName: "Avatar of Justice"
                )
            ],
            at: .now
        )

        #expect(items.count == 1)
        #expect(items[0].text == "Avatar of Justice")
        #expect(items[0].visualRole == .beneficialStatus)
        #expect(items[0].sourceEventIDs == [10, 11, 12])
    }
}
