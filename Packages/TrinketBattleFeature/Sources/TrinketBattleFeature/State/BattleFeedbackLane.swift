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
    var nextVisualStartByTarget: [String: Date] = [:]
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
        let prepared = CombatFeedbackPresenter.makeItems(from: events, at: date)
        guard !prepared.isEmpty else { return }
        var newScheduledItems: [CombatFeedbackItem] = []
        var updatedItems: [CombatFeedbackItem] = []

        for item in prepared {
            if let updated = tryAbsorb(item, at: date) {
                updatedItems.append(updated)
                continue
            }

            let scheduled = schedule(item, at: date)
            newScheduledItems.append(scheduled)
        }

        if !newScheduledItems.isEmpty {
            activeItems.append(contentsOf: newScheduledItems)
        }

        if !updatedItems.isEmpty {
            publish(.update(updatedItems))
        }
        if !newScheduledItems.isEmpty {
            publish(.insert(newScheduledItems))
        }
        applyMultimodalPresentation(for: prepared, environment: environment)
        updatePruneDate()
    }

    private func tryAbsorb(_ item: CombatFeedbackItem, at date: Date) -> CombatFeedbackItem? {
        guard let matchIndex = activeItems.lastIndex(where: { existing in
            existing.targetID == item.targetID
                && existing.keyword == item.keyword
                && existing.feedbackClass == item.feedbackClass
                && existing.reactionKind == item.reactionKind
                && existing.visualRole == item.visualRole
                && date >= existing.availableAt
                && date < existing.expiresAt
                && date.timeIntervalSince(existing.firstScheduledAt) < BattleMotion.maxContinuousChipLifetime
                && existing.label.merging(with: item.label) != nil
        }) else { return nil }

        let existing = activeItems[matchIndex]
        guard let mergedLabel = existing.label.merging(with: item.label) else { return nil }

        var updated = existing
        updated.sourceEventIDs += item.sourceEventIDs
        updated.label = mergedLabel
        updated.availableAt = date
        updated.expiresAt = date.addingTimeInterval(BattleMotion.chipDisplayDuration)
        activeItems[matchIndex] = updated
        return updated
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
        nextVisualStartByTarget.removeAll(keepingCapacity: true)
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

    private func schedule(
        _ item: CombatFeedbackItem,
        at date: Date,
    ) -> CombatFeedbackItem {
        let start = max(date, nextVisualStartByTarget[item.targetID] ?? .distantPast)
        nextVisualStartByTarget[item.targetID] = start.addingTimeInterval(
            BattleMotion.feedbackStreamStagger,
        )
        return item.scheduled(at: start)
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
        var reactedActionIDs = Set<Int>()
        for item in due where item.presentationIndex == 0
            && item.reactionKind != .none
            && reactedActionIDs.insert(item.actionGroupID).inserted {
            hitReactionsByTargetID[item.targetID] = CombatantHitReaction(
                id: item.id,
                kind: item.reactionKind,
            )
            reactedTargetIDs.insert(item.targetID)
        }
        if !reactedTargetIDs.isEmpty {
            noteHitReactionsChanged(for: reactedTargetIDs)
        }
    }
}
