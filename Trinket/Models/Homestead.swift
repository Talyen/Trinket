import SwiftUI

extension HomesteadResource {
    var displayName: String {
        switch self {
        case .wood: return "Wood"
        case .stone: return "Stone"
        case .iron: return "Iron"
        case .food: return "Food"
        case .herbs: return "Herbs"
        case .crystal: return "Crystal"
        case .gold: return "Gold"
        }
    }

    var symbolName: String {
        switch self {
        case .wood: return "tree.fill"
        case .stone: return "mountain.2.fill"
        case .iron: return "hammer.fill"
        case .food: return "carrot.fill"
        case .herbs: return "leaf.fill"
        case .crystal: return "sparkles"
        case .gold: return "dollarsign.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .wood: return .brown
        case .stone: return Color(red: 0.58, green: 0.54, blue: 0.48)
        case .iron: return Color(red: 0.30, green: 0.39, blue: 0.48)
        case .food: return .orange
        case .herbs: return .green
        case .crystal: return .blue
        case .gold: return Keyword.gold.visualStyle.color
        }
    }
}

extension PlayerHomesteadState {
    func isUnlocked(_ definition: HomesteadNodeDefinition) -> Bool {
        definition.prerequisites.allSatisfy { tier(for: $0.nodeID) >= $0.minimumTier }
    }

    func nextTier(for definition: HomesteadNodeDefinition) -> HomesteadNodeTier? {
        definition.tier(tier(for: definition.id) + 1)
    }

    func canAfford(_ tier: HomesteadNodeTier, roster: PlayerRosterState) -> Bool {
        tier.cost.allSatisfy { balance(for: $0.resource, roster: roster) >= $0.quantity }
    }

    func isComplete(_ definition: HomesteadNodeDefinition) -> Bool {
        tier(for: definition.id) >= definition.maxTier
    }

    mutating func buildOrUpgrade(_ definition: HomesteadNodeDefinition, roster: inout PlayerRosterState) -> Bool {
        guard isUnlocked(definition),
              let tier = nextTier(for: definition),
              canAfford(tier, roster: roster)
        else { return false }

        for amount in tier.cost {
            if amount.resource == .gold {
                roster.gold -= amount.quantity
            } else {
                resources[amount.resource, default: 0] -= amount.quantity
            }
        }
        nodeTiers[definition.id, default: 0] += 1
        return true
    }
}
