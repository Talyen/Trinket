import TrinketContent
import TrinketCore
import TrinketPersistence

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
        var built = 0
        var total = 0
        for definition in GameContent.homesteadNodes where definition.category == category {
            built += homestead.tier(for: definition.id)
            total += definition.maxTier
        }
        builtTiers = built
        totalTiers = total
    }
}
