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

public enum HomesteadTierConnectorState: Equatable, Sendable {
    case completed
    case progressed
    case future
}

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

    public var overviewEffect: HomesteadBonus? {
        guard currentTier > 0 else { return nil }
        return definition.tier(currentTier)?.bonus
    }

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

    public func tierPathConnectors(for tierIndex: Int) -> (
        before: HomesteadTierConnectorState?,
        after: HomesteadTierConnectorState?,
    ) {
        let tierCount = definition.tiers.count
        let before = tierIndex == 0
            ? nil
            : connectorState(for: tierPathState(for: definition.tiers[tierIndex]))
        let after = tierIndex >= tierCount - 1
            ? nil
            : connectorState(for: tierPathState(for: definition.tiers[tierIndex + 1]))
        return (before, after)
    }

    private func connectorState(for state: HomesteadTierPathState) -> HomesteadTierConnectorState {
        switch state {
        case .completed: .completed
        case .next: .progressed
        case .future, .locked: .future
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
        case let .unbuilt(affordable): affordable ? TrinketDesign.Colors.accent : .secondary
        case .built: .secondary
        case .upgradeReady: TrinketDesign.Colors.accent
        case .completed: TrinketDesign.Colors.success
        }
    }

    public func balance(for amount: ResourceAmount) -> Int {
        homestead.balance(for: amount.resource, roster: roster)
    }

    public func hasEnough(_ amount: ResourceAmount) -> Bool {
        balance(for: amount) >= amount.quantity
    }

    public init(
        definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadState,
        roster: PlayerRosterState,
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
        case 4: "IV"
        default: "\(tier)"
        }
        return "\(nodeTitle) \(suffix)"
    }
}

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
