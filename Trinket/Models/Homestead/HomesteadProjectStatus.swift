import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

enum HomesteadProjectRowState: Equatable {
    case prerequisiteLocked
    case unbuilt(affordable: Bool)
    case built
    case upgradeReady
    case completed
}

enum HomesteadTierPathState: Equatable {
    case completed
    case next(affordable: Bool)
    case future
    case locked
}

enum HomesteadFooterState: Equatable {
    case action(title: String, enabled: Bool, reason: String?)
    case complete
}

/// Derived presentation state for Homestead rows, the tier path, and its
/// persistent action footer. Nothing here is persisted or used by game rules.
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

    /// The effect visible in the overview row. Unbuilt and locked projects
    /// intentionally preview tier one; built projects show only their active tier.
    var overviewEffect: HomesteadBonus? {
        let visibleTier = max(currentTier, 1)
        return definition.tier(visibleTier)?.bonus
    }

    var rowState: HomesteadProjectRowState {
        if !isUnlocked {
            return .prerequisiteLocked
        }
        if isComplete {
            return .completed
        }
        if currentTier == 0 {
            return .unbuilt(affordable: isAffordable)
        }
        return isAffordable ? .upgradeReady : .built
    }

    func tierPathState(for tier: HomesteadNodeTier) -> HomesteadTierPathState {
        if !isUnlocked {
            return .locked
        }
        if tier.tier <= currentTier {
            return .completed
        }
        if tier.tier == currentTier + 1 {
            return .next(affordable: isAffordable)
        }
        return .future
    }

    /// Connector segments for the shared vertical path rail (Stage-select style).
    func tierPathConnectors(for tierIndex: Int) -> (
        before: PathConnectorState?,
        after: PathConnectorState?
    ) {
        let states = definition.tiers.map(tierPathState(for:))
        let connectorBefore: PathConnectorState? = tierIndex == 0
            ? nil
            : (isFuturePathState(states[tierIndex]) ? .future : .progressed)
        let connectorAfter: PathConnectorState? = tierIndex == definition.tiers.count - 1
            ? nil
            : (isFuturePathState(states[tierIndex + 1]) ? .future : .progressed)
        return (connectorBefore, connectorAfter)
    }

    private func isFuturePathState(_ state: HomesteadTierPathState) -> Bool {
        switch state {
        case .future, .locked: true
        case .completed, .next: false
        }
    }

    var footerState: HomesteadFooterState {
        guard let nextTier else { return .complete }

        let title = nextTier.tier == 1 ? "Build" : "Upgrade"
        let enabled = canBuildOrUpgrade
        let reason: String? = if !isUnlocked {
            unlockRequirementText
        } else if !isAffordable {
            missingResourceText ?? "Gather materials to continue."
        } else {
            nil
        }
        return .action(title: title, enabled: enabled, reason: reason)
    }

    var actionTitle: String {
        switch footerState {
        case let .action(title, _, _): title
        case .complete: "Complete"
        }
    }

    var statusTitle: String {
        switch rowState {
        case .prerequisiteLocked: "Locked"
        case let .unbuilt(affordable): affordable ? "Ready to Build" : "Unbuilt"
        case .built: "Built"
        case .upgradeReady: "Ready to Upgrade"
        case .completed: "Complete"
        }
    }

    var statusSymbolName: String {
        switch rowState {
        case .prerequisiteLocked: "lock.fill"
        case let .unbuilt(affordable): affordable ? "arrowshape.up.fill" : "chevron.right"
        case .built: "chevron.right"
        case .upgradeReady: "arrowshape.up.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    var statusColor: Color {
        switch rowState {
        case .prerequisiteLocked: .secondary
        case let .unbuilt(affordable): affordable ? definition.tint : .secondary
        case .built: .secondary
        case .upgradeReady: definition.tint
        case .completed: TrinketDesign.Colors.success
        }
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
        return "Need \(missing.count) materials"
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

enum HomesteadTierCopy {
    static func title(for tier: Int, nodeTitle: String) -> String {
        let suffix = switch tier {
        case 1: "I"
        case 2: "II"
        case 3: "III"
        default: "\(tier)"
        }
        return "\(nodeTitle) \(suffix)"
    }
}
