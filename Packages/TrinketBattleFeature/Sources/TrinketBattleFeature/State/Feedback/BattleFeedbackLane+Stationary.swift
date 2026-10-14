import Foundation
import TrinketCore

extension BattleFeedbackLane {
    func recordStationary(_ item: CombatFeedbackItem, at date: Date, candidates: inout CombatFeedbackMergeCandidates) -> Int {
        let index = candidates.indices(for: item).reversed().first { index in
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
                let previous = activeItems[index]
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
                candidates.didMerge(previous: previous, current: activeItems[index], at: index)
                return index
            }
        }
        var scheduled = incoming.scheduled(at: date)
        if case .amount = incoming.label {
            scheduled.reservedDigitCount = incoming.label.displayString.count + 1
        }
        activeItems.append(scheduled)
        let insertedIndex = activeItems.count - 1
        candidates.append(scheduled, at: insertedIndex)
        return insertedIndex
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
            var winners: [String: (first: CornerCandidate, second: CornerCandidate?)] = [:]
            for item in activeItems where item.region == region && !evictedItemIDs.contains(item.id) {
                let candidate = CornerCandidate(item)
                guard var pair = winners[item.targetID] else {
                    winners[item.targetID] = (candidate, nil)
                    continue
                }
                // Keep the same stable top two without sorting or retaining the whole burst.
                if candidate.outranks(pair.first) {
                    if let displaced = pair.second {
                        evictedItemIDs.insert(displaced.id)
                    }
                    pair = (candidate, pair.first)
                } else if let second = pair.second {
                    if candidate.outranks(second) {
                        evictedItemIDs.insert(second.id)
                        pair.second = candidate
                    } else {
                        evictedItemIDs.insert(candidate.id)
                    }
                } else {
                    pair.second = candidate
                }
                winners[item.targetID] = pair
            }
        }
    }
}

struct CombatFeedbackMergeCandidates {
    private struct Key: Hashable {
        let targetID: String
        let region: CombatFeedbackRegion
        let keyword: Keyword
        let feedbackClass: CombatFeedbackClass
        let visualRole: CombatFeedbackVisualRole

        init(_ item: CombatFeedbackItem) {
            targetID = item.targetID
            region = item.region
            keyword = item.keyword
            feedbackClass = item.feedbackClass
            visualRole = item.visualRole
        }
    }

    private var positions: [Key: [Int]] = [:]

    init(items: [CombatFeedbackItem]) {
        for (index, item) in items.enumerated() {
            append(item, at: index)
        }
    }

    func indices(for item: CombatFeedbackItem) -> [Int] {
        positions[Key(item)] ?? []
    }

    mutating func append(_ item: CombatFeedbackItem, at index: Int) {
        positions[Key(item), default: []].append(index)
    }

    mutating func didMerge(previous: CombatFeedbackItem, current: CombatFeedbackItem, at index: Int) {
        let oldKey = Key(previous)
        let newKey = Key(current)
        guard oldKey != newKey else { return }
        positions[oldKey]?.removeAll { $0 == index }
        positions[newKey, default: []].append(index)
        positions[newKey]?.sort()
    }
}

private struct CornerCandidate {
    let id: Int
    let isImportant: Bool
    let lastReceivedAt: Date
    let latestEventID: Int

    init(_ item: CombatFeedbackItem) {
        id = item.id
        isImportant = item.effectKind == .controlTriggered || item.feedbackClass == .deathsDoor
        lastReceivedAt = item.lastReceivedAt
        latestEventID = item.sourceEventIDs.max() ?? item.id
    }

    func outranks(_ other: Self) -> Bool {
        if isImportant != other.isImportant {
            return isImportant
        }
        if lastReceivedAt != other.lastReceivedAt {
            return lastReceivedAt > other.lastReceivedAt
        }
        return latestEventID > other.latestEventID
    }
}
