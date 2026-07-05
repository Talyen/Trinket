import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct HomesteadProjectStatus {
    let definition: HomesteadNodeDefinition
    let homestead: PlayerHomesteadState
    let roster: PlayerRosterState

    var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    var isUnlocked: Bool {
        homestead.isUnlocked(definition)
    }

    var isComplete: Bool {
        homestead.isComplete(definition)
    }

    var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    var canBuildOrUpgrade: Bool {
        isUnlocked && isAffordable && !isComplete
    }

    var nextBonus: HomesteadBonus? {
        nextTier?.bonus
    }

    var actionTitle: String {
        guard let nextTier else { return "Complete" }
        return nextTier.tier == 1 ? "Build" : "Upgrade"
    }

    var statusTitle: String {
        if isComplete { return "Complete" }
        if !isUnlocked { return unlockRequirementText }
        if canBuildOrUpgrade { return nextTier?.tier == 1 ? "Ready to Build" : "Ready to Upgrade" }
        return missingResourceText ?? "Gather Materials"
    }

    var statusSymbolName: String {
        if isComplete { return "checkmark.seal.fill" }
        if !isUnlocked { return "lock.fill" }
        if canBuildOrUpgrade { return "hammer.fill" }
        return "shippingbox.fill"
    }

    var statusColor: Color {
        if isComplete { return TrinketDesign.Colors.success }
        if !isUnlocked { return .secondary }
        if canBuildOrUpgrade { return definition.tint }
        return .secondary
    }

    var missingResources: [ResourceAmount] {
        guard let nextTier else { return [] }
        return nextTier.cost.compactMap { amount in
            let missing = amount.quantity - balance(for: amount)
            guard missing > 0 else { return nil }
            return ResourceAmount(amount.resource, missing)
        }
    }

    var missingResourceText: String? {
        let missing = missingResources
        guard !missing.isEmpty else { return nil }
        if missing.count == 1, let first = missing.first {
            return "Need \(first.quantity) \(first.resource.displayName)"
        }
        return "Need \(missing.count) Materials"
    }

    var unlockRequirementText: String {
        let unmet = definition.prerequisites.first { homestead.tier(for: $0.nodeID) < $0.minimumTier }
        guard let unmet else { return "Locked" }
        let title = GameContent.homesteadNode(matching: unmet.nodeID)?.title ?? unmet.nodeID.rawValue
        return "Requires \(title)"
    }

    func balance(for amount: ResourceAmount) -> Int {
        homestead.balance(for: amount.resource, roster: roster)
    }

    func hasEnough(_ amount: ResourceAmount) -> Bool {
        balance(for: amount) >= amount.quantity
    }

    var detailBuildButtonAccessibilityID: String {
        if currentTier == 0 {
            return "Build \(definition.title) Button"
        }
        return "Upgrade \(definition.title) Button"
    }
}
