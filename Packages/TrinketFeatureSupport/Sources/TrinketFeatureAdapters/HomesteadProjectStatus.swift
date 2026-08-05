import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

public enum HomesteadProjectRowState: Equatable {
    case prerequisiteLocked
    case unbuilt(affordable: Bool)
    case built
    case upgradeReady
    case completed
}

public enum HomesteadTierPathState: Equatable {
    case completed
    case next(affordable: Bool)
    case future
    case locked
}

public enum HomesteadFooterState: Equatable {
    case action(title: String, enabled: Bool, reason: String?)
    case complete
}

/// Derived presentation state for Homestead rows, the tier path, and its
/// persistent action footer. Nothing here is persisted or used by game rules.
public struct HomesteadProjectStatus {
    public let definition: HomesteadNodeDefinition
    public let homestead: PlayerHomesteadState
    public let roster: PlayerRosterState

    public var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    public var nextTier: HomesteadNodeTier? {
        homestead.nextTier(for: definition)
    }

    public var isUnlocked: Bool {
        homestead.isUnlocked(definition)
    }

    public var isComplete: Bool {
        homestead.isComplete(definition)
    }

    public var isAffordable: Bool {
        nextTier.map { homestead.canAfford($0, roster: roster) } ?? false
    }

    public var canBuildOrUpgrade: Bool {
        isUnlocked && isAffordable && !isComplete
    }

    /// The active bonus for built projects. Unbuilt and locked projects have none.
    public var overviewEffect: HomesteadBonus? {
        guard currentTier > 0 else { return nil }
        return definition.tier(currentTier)?.bonus
    }

    /// Caption under the project title on the overview row.
    public var overviewCaption: String {
        if currentTier == 0 {
            return "Not Yet Constructed"
        }
        return overviewEffect?.description ?? definition.summary
    }

    public var rowState: HomesteadProjectRowState {
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

    public func tierPathState(for tier: HomesteadNodeTier) -> HomesteadTierPathState {
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
    public func tierPathConnectors(for tierIndex: Int) -> (
        before: PathConnectorState?,
        after: PathConnectorState?
    ) {
        let states = definition.tiers.map(tierPathState(for:))
        return PathConnectorState.pair(
            at: tierIndex,
            count: definition.tiers.count,
            isFuture: { isFuturePathState(states[$0]) }
        )
    }

    private func isFuturePathState(_ state: HomesteadTierPathState) -> Bool {
        switch state {
        case .future, .locked: true
        case .completed, .next: false
        }
    }

    public var footerState: HomesteadFooterState {
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

    public var actionTitle: String {
        switch footerState {
        case let .action(title, _, _): title
        case .complete: "Complete"
        }
    }

    public var statusTitle: String {
        switch rowState {
        case .prerequisiteLocked: "Locked"
        case let .unbuilt(affordable): affordable ? "Ready to Build" : "Unbuilt"
        case .built: "Built"
        case .upgradeReady: "Ready to Upgrade"
        case .completed: "Complete"
        }
    }

    public var statusSymbolName: String {
        switch rowState {
        case .prerequisiteLocked: "lock.fill"
        case let .unbuilt(affordable): affordable ? "arrowshape.up.fill" : "chevron.right"
        case .built: "chevron.right"
        case .upgradeReady: "arrowshape.up.fill"
        case .completed: "checkmark.circle.fill"
        }
    }

    public var statusColor: Color {
        switch rowState {
        case .prerequisiteLocked: .secondary
        case let .unbuilt(affordable): affordable ? definition.tint : .secondary
        case .built: .secondary
        case .upgradeReady: definition.tint
        case .completed: TrinketDesign.Colors.success
        }
    }

    public var missingResources: [ResourceAmount] {
        guard let nextTier else { return [] }
        return nextTier.cost.compactMap { amount in
            let missing = amount.quantity - balance(for: amount)
            guard missing > 0 else { return nil }
            return ResourceAmount(amount.resource, missing)
        }
    }

    public var missingResourceText: String? {
        let missing = missingResources
        guard !missing.isEmpty else { return nil }
        if missing.count == 1, let first = missing.first {
            return "Need \(first.quantity) \(first.resource.displayName)"
        }
        return "Need \(missing.count) materials"
    }

    public var unlockRequirementText: String {
        let unmet = definition.prerequisites.first { homestead.tier(for: $0.nodeID) < $0.minimumTier }
        guard let unmet else { return "Locked" }
        let title = GameContent.homesteadNode(matching: unmet.nodeID)?.title ?? unmet.nodeID.rawValue
        return "Requires \(title)"
    }

    public func balance(for amount: ResourceAmount) -> Int {
        homestead.balance(for: amount.resource, roster: roster)
    }

    public func hasEnough(_ amount: ResourceAmount) -> Bool {
        balance(for: amount) >= amount.quantity
    }

    public var detailBuildButtonAccessibilityID: String {
        if currentTier == 0 {
            return "Build \(definition.title) Button"
        }
        return "Upgrade \(definition.title) Button"
    }

    public init(
        definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState
    ) {
        self.definition = definition
        self.homestead = homestead
        self.roster = roster
    }
}

public enum HomesteadTierCopy {
    public static func title(for tier: Int, nodeTitle: String) -> String {
        let suffix = switch tier {
        case 1: "I"
        case 2: "II"
        case 3: "III"
        default: "\(tier)"
        }
        return "\(nodeTitle) \(suffix)"
    }
}

/// Category-level construction progress for overview cards.
public struct HomesteadCategoryProgress {
    public let builtTiers: Int
    public let totalTiers: Int

    public var subtitle: String {
        "\(builtTiers) / \(totalTiers)"
    }

    public init(category: HomesteadNodeCategory, homestead: PlayerHomesteadState) {
        let definitions = GameContent.homesteadNodes.filter { $0.category == category }
        builtTiers = definitions.reduce(0) { $0 + homestead.tier(for: $1.id) }
        totalTiers = definitions.reduce(0) { $0 + $1.maxTier }
    }
}
