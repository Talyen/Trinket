import BattleEngine
import Foundation
import Observation
import TrinketDesignSystem
import TrinketFeatureSupport

@MainActor
@Observable
final class BattleFeedbackLane {
    @ObservationIgnored
    var activeItems: [CombatFeedbackItem] = []
    @ObservationIgnored
    var hitReactionsByTargetID: [String: CombatantHitReaction] = [:]
    @ObservationIgnored
    var attackReactionsByCombatantID: [String: CombatantAttackReaction] = [:]
    @ObservationIgnored
    var celebrateReactionExpiresAt: [String: Date] = [:]
    @ObservationIgnored
    var nextPruneAt: Date?
    @ObservationIgnored
    var scheduler: FeedbackDeadlineTimer?

    @ObservationIgnored
    private var bridges: [(
        ownerID: UUID,
        onChange: (CombatFeedbackUpdate) -> Void,
    )] = []
    @ObservationIgnored
    private var hitReactionBridges: [(
        ownerID: UUID,
        combatantID: String,
        onChange: (CombatantHitReaction?) -> Void,
    )] = []
    @ObservationIgnored
    private var attackReactionBridges: [(
        ownerID: UUID,
        combatantID: String,
        onChange: (CombatantAttackReaction?) -> Void,
    )] = []

    func installBridge(
        ownerID: UUID,
        onChange: @escaping (CombatFeedbackUpdate) -> Void,
    ) {
        bridges.removeAll { $0.ownerID == ownerID }
        bridges.append((ownerID, onChange))
    }

    func uninstallBridge(ownerID: UUID) {
        bridges.removeAll { $0.ownerID == ownerID }
    }

    func installHitReactionBridge(
        ownerID: UUID,
        combatantID: String,
        onChange: @escaping (CombatantHitReaction?) -> Void,
    ) {
        hitReactionBridges.removeAll { $0.ownerID == ownerID }
        hitReactionBridges.append((ownerID, combatantID, onChange))
        onChange(hitReactionsByTargetID[combatantID])
    }

    func uninstallHitReactionBridge(ownerID: UUID) {
        hitReactionBridges.removeAll { $0.ownerID == ownerID }
    }

    func installAttackReactionBridge(
        ownerID: UUID,
        combatantID: String,
        onChange: @escaping (CombatantAttackReaction?) -> Void,
    ) {
        attackReactionBridges.removeAll { $0.ownerID == ownerID }
        attackReactionBridges.append((ownerID, combatantID, onChange))
        onChange(attackReactionsByCombatantID[combatantID])
    }

    func uninstallAttackReactionBridge(ownerID: UUID) {
        attackReactionBridges.removeAll { $0.ownerID == ownerID }
    }

    func publish(_ update: CombatFeedbackUpdate) {
        for bridge in bridges {
            bridge.onChange(update)
        }
    }

    func noteItemsChanged() {
        publish(.replace(activeItems))
    }

    func noteHitReactionsChanged(for combatantIDs: Set<String>) {
        for bridge in hitReactionBridges where combatantIDs.contains(bridge.combatantID) {
            bridge.onChange(hitReactionsByTargetID[bridge.combatantID])
        }
    }

    func noteAttackReactionsChanged(for combatantID: String) {
        let reaction = attackReactionsByCombatantID[combatantID]
        for bridge in attackReactionBridges where bridge.combatantID == combatantID {
            bridge.onChange(reaction)
        }
    }

    func resetPresentation() {
        for bridge in hitReactionBridges {
            bridge.onChange(nil)
        }
        for bridge in attackReactionBridges {
            bridge.onChange(nil)
        }
        publish(.reset)
    }

    func record(
        _ events: [ActionEvent],
        at date: Date = .now,
        environment: BattleRuntimeDependencies = .silent,
    ) {
        pruneExpired(at: date)
        let knownIDs = Set(activeItems.flatMap(\.sourceEventIDs))
        let prepared = CombatFeedbackPresenter.makeItems(from: events.filter { !knownIDs.contains($0.id) }, at: date)
        guard !prepared.isEmpty else { return }

        for item in prepared {
            let existingGroup = activeItems.first {
                $0.targetID == item.targetID && $0.actionGroupID == item.actionGroupID && $0.retiringAt == nil
            }
            if existingGroup == nil {
                if let reaction = hitReactionsByTargetID[item.targetID], activeItems.contains(where: {
                    $0.targetID == item.targetID && $0.retiringAt != nil && $0.sourceEventIDs.contains(reaction.id)
                }) {
                    hitReactionsByTargetID.removeValue(forKey: item.targetID)
                    noteHitReactionsChanged(for: [item.targetID])
                }
                activeItems.removeAll { $0.targetID == item.targetID && $0.retiringAt != nil }
                for index in activeItems.indices where activeItems[index].targetID == item.targetID {
                    activeItems[index].retiringAt = date
                    activeItems[index].expiresAt = min(
                        activeItems[index].expiresAt,
                        date.addingTimeInterval(BattleMotion.feedbackHandoffDuration),
                    )
                }
            }
            let start = existingGroup?.firstScheduledAt ?? date
            let expiry = min(
                date.addingTimeInterval(BattleMotion.chipDisplayDuration),
                start.addingTimeInterval(BattleMotion.maxContinuousChipLifetime),
            )
            if let index = activeItems.firstIndex(where: { existing in
                existing.targetID == item.targetID && existing.actionGroupID == item.actionGroupID
                    && existing.retiringAt == nil && existing.keyword == item.keyword
                    && existing.feedbackClass == item.feedbackClass && existing.visualRole == item.visualRole
                    && existing.label.merging(with: item.label) != nil
            }), let merged = activeItems[index].label.merging(with: item.label) {
                activeItems[index].label = merged
                activeItems[index].sourceEventIDs += item.sourceEventIDs
                activeItems[index].lastUpdatedAt = date
                activeItems[index].isCritical = activeItems[index].isCritical || item.isCritical
                if item.isCritical {
                    activeItems[index].criticalAt = date
                }
            } else {
                var scheduled = item.scheduled(at: start)
                scheduled.criticalAt = item.isCritical ? date : nil
                activeItems.append(scheduled)
            }
            for index in activeItems.indices where activeItems[index].targetID == item.targetID
                && activeItems[index].actionGroupID == item.actionGroupID && activeItems[index].retiringAt == nil {
                activeItems[index].expiresAt = expiry
            }
        }
        noteItemsChanged()
        applyMultimodalPresentation(for: prepared, environment: environment)
        updatePruneDate()
    }

    func prepareScheduler() {
        _ = resolvedScheduler()
    }

    func pruneExpired(at date: Date = .now) {
        var removedItemIDs: Set<Int> = []
        var reactedTargetIDsToNotify: Set<String> = []
        var remainingItems: [CombatFeedbackItem] = []
        remainingItems.reserveCapacity(activeItems.count)

        for item in activeItems {
            if date >= item.expiresAt {
                removedItemIDs.insert(item.id)
                let clearedReaction = hitReactionsByTargetID[item.targetID].map { reaction in
                    item.sourceEventIDs.contains(reaction.id)
                } ?? false
                if clearedReaction {
                    hitReactionsByTargetID.removeValue(forKey: item.targetID)
                    reactedTargetIDsToNotify.insert(item.targetID)
                }
            } else {
                remainingItems.append(item)
            }
        }
        activeItems = remainingItems

        for targetID in celebrateReactionExpiresAt.keys {
            guard let expiresAt = celebrateReactionExpiresAt[targetID], date >= expiresAt else { continue }
            celebrateReactionExpiresAt.removeValue(forKey: targetID)
            if hitReactionsByTargetID[targetID]?.kind == .celebrate {
                hitReactionsByTargetID.removeValue(forKey: targetID)
                reactedTargetIDsToNotify.insert(targetID)
            }
        }

        if !reactedTargetIDsToNotify.isEmpty {
            noteHitReactionsChanged(for: reactedTargetIDsToNotify)
        }
        if !removedItemIDs.isEmpty {
            publish(.remove(removedItemIDs))
        }
        updatePruneDate()
    }

    func clear() {
        let hadPublishedPresentation = !activeItems.isEmpty
            || !hitReactionsByTargetID.isEmpty
            || !attackReactionsByCombatantID.isEmpty
        nextPruneAt = nil
        celebrateReactionExpiresAt.removeAll(keepingCapacity: true)
        scheduler?.cancel()
        activeItems = []
        hitReactionsByTargetID = [:]
        attackReactionsByCombatantID = [:]
        if hadPublishedPresentation {
            resetPresentation()
        }
    }

    func release() {
        clear()
        scheduler = nil
    }

    func updatePruneDate() {
        let chipExpiry = activeItems.lazy.map(\.expiresAt).min()
        let celebrationExpiry = celebrateReactionExpiresAt.values.min()
        nextPruneAt = [chipExpiry, celebrationExpiry].compactMap(\.self).min()?
            .addingTimeInterval(0.02)
        if let nextPruneAt {
            resolvedScheduler().schedule(at: nextPruneAt)
        } else {
            scheduler?.cancel()
        }
    }

    private func resolvedScheduler() -> FeedbackDeadlineTimer {
        let scheduler = scheduler ?? FeedbackDeadlineTimer { [weak self] in
            self?.pruneExpired()
        }
        self.scheduler = scheduler
        return scheduler
    }

    private func applyMultimodalPresentation(
        for due: [CombatFeedbackItem],
        environment: BattleRuntimeDependencies,
    ) {
        guard !due.isEmpty else { return }

        environment.playSFX(CombatSFXMapper.uniqueClipIDs(for: due))

        var reactedTargetIDs: Set<String> = []
        for item in due where item.reactionKind != .none
            && reactedTargetIDs.insert(item.targetID).inserted {
            hitReactionsByTargetID[item.targetID] = CombatantHitReaction(
                id: item.id,
                kind: item.isCritical && item.reactionKind == .damage ? .critical : item.reactionKind,
            )
        }
        if !reactedTargetIDs.isEmpty {
            noteHitReactionsChanged(for: reactedTargetIDs)
        }
    }
}
