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

public struct HomesteadProjectStatus {
    public let definition: HomesteadNodeDefinition
    public let homestead: PlayerHomesteadState
    public let roster: PlayerRosterState

    public var currentTier: Int {
        homestead.tier(for: definition.id)
    }

    public var currentStage: HomesteadNodeTier? {
        definition.tier(currentTier)
    }

    public var missingPrerequisites: [HomesteadNodeRequirement] {
        definition.prerequisites.filter { homestead.tier(for: $0.nodeID) < $0.minimumTier }
    }

    public var materialShortfalls: [ResourceAmount] {
        nextTier?.cost.compactMap { amount in
            let missing = amount.quantity - balance(for: amount)
            return missing > 0 ? ResourceAmount(amount.resource, missing) : nil
        } ?? []
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
