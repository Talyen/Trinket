import Foundation

extension BattleFeedbackLane {
    func recordStationary(_ item: CombatFeedbackItem, at date: Date) {
        let index = activeItems.indices.reversed().first { index in
            let existing = activeItems[index]
            guard existing.usesStationaryExperiment, !evictedItemIDs.contains(existing.id),
                  existing.targetID == item.targetID, existing.keyword == item.keyword,
                  existing.feedbackClass == item.feedbackClass, existing.visualRole == item.visualRole,
                  date < existing.firstScheduledAt.addingTimeInterval(StationaryFeedbackLayout.fadeStart),
                  let merged = existing.label.merging(with: item.label)
            else { return false }
            if case .amount = merged {
                return merged.displayString.count <= existing.reservedDigitCount
            }
            return true
        }
        if let index, let merged = activeItems[index].label.merging(with: item.label) {
            if [.directDamage, .critical, .dot].contains(item.feedbackClass),
               case let .amount(previous, _) = activeItems[index].label,
               case let .amount(updated, _) = merged, updated.magnitude > previous.magnitude {
                activeItems[index].lastUpdatedAt = date
            }
            activeItems[index].label = merged
            activeItems[index].sourceEventIDs += item.sourceEventIDs
            activeItems[index].isCritical = activeItems[index].isCritical || item.isCritical
            if item.isCritical {
                activeItems[index].criticalAt = date
            }
        } else {
            var scheduled = item.scheduled(at: date)
            scheduled.usesStationaryExperiment = true
            scheduled.expiresAt = date.addingTimeInterval(StationaryFeedbackLayout.lifetime)
            if case .amount = item.label {
                scheduled.reservedDigitCount = item.label.displayString.count + 1
            }
            activeItems.append(scheduled)
        }
    }
}
