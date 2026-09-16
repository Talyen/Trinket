import BattleEngine
import Foundation
import Observation
import TrinketCore
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

    @ObservationIgnored var scheduledActions: [BattleScheduledAction] = []
    @ObservationIgnored var nextActionBeatID = 0
    @ObservationIgnored var nextAttackReactionID = 0
    @ObservationIgnored var nextRecordedHitID = Int.min
    @ObservationIgnored var recordedHitExpirations: [String: (id: Int, date: Date)] = [:]
    @ObservationIgnored var attackOwners: [String: Int] = [:]
    @ObservationIgnored var previewActors: Set<String> = []
    @ObservationIgnored var suspendedAt: Date?
    @ObservationIgnored weak var automaticPlayback: BattleCardPlaybackState?

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
        actionGroupID: Int? = nil,
        damage: [BattleResolvedDamage] = [],
    ) {
        pruneExpired(at: date)
        let knownIDs = Set(activeItems.flatMap(\.sourceEventIDs))
        let prepared = CombatFeedbackPresenter.makeItems(
            from: events.filter { !knownIDs.contains($0.id) },
            at: date,
            actionGroupID: actionGroupID,
        )
        guard !prepared.isEmpty || !damage.isEmpty else { return }

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
        applyMultimodalPresentation(for: prepared, damage: damage, at: date, environment: environment)
        updatePruneDate()
    }

    func prepareScheduler() {
        _ = resolvedScheduler()
    }

    func pruneExpired(at date: Date = .now) {
        guard suspendedAt == nil else { return }
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
        for (targetID, expiry) in recordedHitExpirations where date >= expiry.date {
            recordedHitExpirations.removeValue(forKey: targetID)
            if hitReactionsByTargetID[targetID]?.id == expiry.id {
                hitReactionsByTargetID.removeValue(forKey: targetID)
                reactedTargetIDsToNotify.insert(targetID)
            }
        }

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
        scheduledActions.removeAll()
        recordedHitExpirations.removeAll()
        attackOwners.removeAll()
        previewActors.removeAll()
        suspendedAt = nil
        automaticPlayback = nil
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
        var expiry = activeItems.lazy.map(\.expiresAt).min()
        if let celebration = celebrateReactionExpiresAt.values.min() {
            expiry = expiry.map { min($0, celebration) } ?? celebration
        }
        if let hit = recordedHitExpirations.values.lazy.map(\.date).min() {
            expiry = expiry.map { min($0, hit) } ?? hit
        }
        let paddedExpiry = expiry?.addingTimeInterval(0.02)
        let actionNext = scheduledActions.lazy.map(\.nextDate).min()
        nextPruneAt = switch (paddedExpiry, actionNext) {
        case let (.some(a), .some(b)): min(a, b)
        case let (.some(a), .none): a
        case let (.none, .some(b)): b
        case (.none, .none): nil
        }
        guard suspendedAt == nil else { return }
        if let nextPruneAt {
            resolvedScheduler().schedule(at: nextPruneAt)
        } else {
            scheduler?.cancel()
        }
    }

    private func resolvedScheduler() -> FeedbackDeadlineTimer {
        let scheduler = scheduler ?? FeedbackDeadlineTimer { [weak self] in
            self?.advance(to: .now)
        }
        self.scheduler = scheduler
        return scheduler
    }

    private func applyMultimodalPresentation(
        for due: [CombatFeedbackItem],
        damage: [BattleResolvedDamage],
        at date: Date,
        environment: BattleRuntimeDependencies,
    ) {
        let damageKeywords = damage.compactMap { damage -> Keyword? in
            if case let .landed(_, healthLost) = damage.impact, healthLost > 0 {
                return damage.keyword
            }
            return nil
        }
        environment.playSFX(CombatSFXMapper.uniqueClipIDs(for: due, damageKeywords: damageKeywords))
        let recordedTargets = Set(damage.filter { $0.reactionKind != nil }.map(\.targetID))
        var reactions: [String: CombatantHitReaction] = [:]
        for (targetID, items) in Dictionary(grouping: due, by: \.targetID) {
            let candidates = items.filter { item in
                item.reactionKind != .none && (!recordedTargets.contains(targetID)
                    || item.reactionKind == .heal || item.reactionKind == .celebrate)
            }
            guard let item = candidates.max(by: {
                $0.reactionPriority < $1.reactionPriority
            }) else { continue }
            reactions[targetID] = CombatantHitReaction(
                id: item.id,
                kind: item.isCritical && item.reactionKind == .damage ? .critical : item.reactionKind,
            )
        }
        for hit in damage {
            guard let kind = hit.reactionKind else { continue }
            if let current = reactions[hit.targetID], current.kind.priority >= kind.priority {
                continue
            }
            nextRecordedHitID += 1
            reactions[hit.targetID] = CombatantHitReaction(id: nextRecordedHitID, kind: kind)
            recordedHitExpirations[hit.targetID] = (nextRecordedHitID, date.addingTimeInterval(BattleMotion.chipDisplayDuration))
        }
        for (targetID, reaction) in reactions {
            hitReactionsByTargetID[targetID] = reaction
        }
        if !reactions.isEmpty {
            noteHitReactionsChanged(for: Set(reactions.keys))
        }
    }
}
