import Foundation

extension BattleFeedbackLane {
    func recordStationary(_ item: CombatFeedbackItem, at date: Date) {
        let index = activeItems.indices.reversed().first { index in
            let existing = activeItems[index]
            guard existing.region == item.region, !evictedItemIDs.contains(existing.id),
                  existing.targetID == item.targetID, existing.keyword == item.keyword,
                  existing.feedbackClass == item.feedbackClass, existing.visualRole == item.visualRole,
                  date < existing.expiresAt.addingTimeInterval(-CombatFeedbackMotionSampler.fadeDuration),
                  let merged = existing.label.merging(with: item.label)
            else { return false }
            if case .amount = merged {
                return merged.displayString.count <= existing.reservedDigitCount
            }
            return true
        }
        if let index, let merged = activeItems[index].label.merging(with: item.label) {
            activeItems[index].lastUpdatedAt = date
            let maximumExpiry = activeItems[index].firstScheduledAt.addingTimeInterval(CombatFeedbackMotionSampler.lifetime + 0.30)
            activeItems[index].expiresAt = min(activeItems[index].expiresAt.addingTimeInterval(0.12), maximumExpiry)
            activeItems[index].label = merged
            activeItems[index].sourceEventIDs += item.sourceEventIDs
            activeItems[index].isCritical = activeItems[index].isCritical || item.isCritical
            if item.isCritical {
                activeItems[index].criticalAt = date
            }
        } else {
            var scheduled = item.scheduled(at: date)
            scheduled.expiresAt = date.addingTimeInterval(CombatFeedbackMotionSampler.lifetime)
            if case .amount = item.label {
                scheduled.reservedDigitCount = item.label.displayString.count + 1
            }
            activeItems.append(scheduled)
        }
    }
}
