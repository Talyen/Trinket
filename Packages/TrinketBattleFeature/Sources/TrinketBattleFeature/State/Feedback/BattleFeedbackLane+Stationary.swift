import Foundation
import TrinketCore

extension BattleFeedbackLane {
    func recordStationary(_ item: CombatFeedbackItem, at date: Date, candidates: inout CombatFeedbackMergeCandidates) -> Int {
        for index in candidates.indices(for: item).reversed() {
            let existing = activeItems[index]
            if date.timeIntervalSince(existing.lastReceivedAt) > 0.25 {
                continue
            }
            guard existing.effectKind == item.effectKind, item.effectKind != .controlTriggered,
                  date < existing.expiresAt.addingTimeInterval(-CombatFeedbackMotionSampler.fadeDuration),
                  let merged = mergedLabel(existing, with: item)
            else { continue }
            // A wider preparation starts a new flight, without searching older matches.
            if case .amount = merged, merged.displayString.count > existing.reservedDigitCount {
                break
            }
            activeItems[index].lastReceivedAt = date
            activeItems[index].label = merged
            activeItems[index].sourceEventIDs += item.sourceEventIDs
            if item.region == .impact {
                activeItems[index].isCritical = existing.isCritical || item.isCritical
                if item.isCritical {
                    activeItems[index].criticalAt = max(date, existing.availableAt)
                }
            }
            return index
        }
        var incoming = item
        if case .amount = incoming.label {
            incoming.reservedDigitCount = incoming.label.displayString.count + 1
        }
        let scheduled = chipBridge.balancedSchedule(
            incoming,
            at: date,
            previous: activeItems,
        )
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
}

struct CombatFeedbackMergeCandidates {
    private struct Key: Hashable {
        let targetID: String
        let region: CombatFeedbackRegion
        let keyword: Keyword
        let feedbackClass: CombatFeedbackClass
        let visualRole: CombatFeedbackVisualRole
        let isPrimaryCardResult: Bool

        init(_ item: CombatFeedbackItem) {
            targetID = item.targetID
            region = item.region
            keyword = item.keyword
            feedbackClass = item.feedbackClass
            visualRole = item.visualRole
            isPrimaryCardResult = item.isPrimaryCardResult
        }
    }

    /// A merge preserves the key: additive amounts keep their sign, words stay
    /// identical, and preparation replacements use an incoming item in the same region.
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
}
