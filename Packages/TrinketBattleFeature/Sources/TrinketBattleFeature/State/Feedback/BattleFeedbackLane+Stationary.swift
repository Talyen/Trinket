import Foundation

extension BattleFeedbackLane {
    func recordStationary(_ item: CombatFeedbackItem, at date: Date) {
        let index = activeItems.indices.reversed().first { index in
            let existing = activeItems[index]
            return existing.region == item.region && !evictedItemIDs.contains(existing.id)
                && existing.targetID == item.targetID && existing.keyword == item.keyword
                && existing.feedbackClass == item.feedbackClass && existing.visualRole == item.visualRole
                && existing.effectKind == item.effectKind && item.effectKind != .controlTriggered
                && date < existing.expiresAt.addingTimeInterval(-CombatFeedbackMotionSampler.fadeDuration)
                && mergedLabel(existing, with: item) != nil
        }
        var incoming = item
        if let index, let merged = mergedLabel(activeItems[index], with: item) {
            if case .amount = merged, merged.displayString.count > activeItems[index].reservedDigitCount {
                if item.effectKind == .partyDamagePreparationApplied {
                    // A wider preparation replaces its old slot rather than leaving two values visible.
                    evictedItemIDs.insert(activeItems[index].id)
                    incoming.sourceEventIDs = activeItems[index].sourceEventIDs + item.sourceEventIDs
                }
            } else {
                activeItems[index].lastReceivedAt = date
                activeItems[index].label = merged
                activeItems[index].sourceEventIDs += item.sourceEventIDs
                if item.region == .impact {
                    activeItems[index].lastUpdatedAt = date
                    let maximumExpiry = activeItems[index].firstScheduledAt.addingTimeInterval(CombatFeedbackMotionSampler.lifetime + 0.30)
                    activeItems[index].expiresAt = min(activeItems[index].expiresAt.addingTimeInterval(0.12), maximumExpiry)
                    activeItems[index].isCritical = activeItems[index].isCritical || item.isCritical
                    if item.isCritical {
                        activeItems[index].criticalAt = date
                    }
                }
                return
            }
        }
        var scheduled = incoming.scheduled(at: date)
        if case .amount = incoming.label {
            scheduled.reservedDigitCount = incoming.label.displayString.count + 1
        }
        activeItems.append(scheduled)
    }

    private func mergedLabel(_ existing: CombatFeedbackItem, with incoming: CombatFeedbackItem) -> CombatFeedbackChipLabel? {
        if incoming.effectKind == .partyDamagePreparationApplied {
            return incoming.label
        }
        guard let merged = existing.label.merging(with: incoming.label) else { return nil }
        if case .amount = merged, merged.displayString.count > existing.reservedDigitCount {
            return nil
        }
        return merged
    }

    func limitCornerItems() {
        for region in [CombatFeedbackRegion.benefit, .setback] {
            let candidates = activeItems.indices.filter {
                activeItems[$0].region == region && !evictedItemIDs.contains(activeItems[$0].id)
            }
            for indices in Dictionary(grouping: candidates, by: { activeItems[$0].targetID }).values {
                let ranked = indices.sorted { lhs, rhs in
                    let left = activeItems[lhs]
                    let right = activeItems[rhs]
                    let leftImportant = left.effectKind == .controlTriggered || left.feedbackClass == .deathsDoor
                    let rightImportant = right.effectKind == .controlTriggered || right.feedbackClass == .deathsDoor
                    if leftImportant != rightImportant {
                        return leftImportant
                    }
                    if left.lastReceivedAt != right.lastReceivedAt {
                        return left.lastReceivedAt > right.lastReceivedAt
                    }
                    return (left.sourceEventIDs.max() ?? left.id) > (right.sourceEventIDs.max() ?? right.id)
                }
                evictedItemIDs.formUnion(ranked.dropFirst(2).map { activeItems[$0].id })
            }
        }
    }
}
