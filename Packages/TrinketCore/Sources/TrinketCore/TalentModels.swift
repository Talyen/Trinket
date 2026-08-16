import Foundation

/// Unique identifier for a talent node in a combatant's talent tree.
public struct TalentNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let keyword: Keyword
    public let symbolName: String
    /// 1-indexed row/tier index: 1 (Foundation), 2 (Synergy), 3 (Mastery).
    public let tier: Int
    public let description: String

    public init(
        id: String,
        name: String,
        keyword: Keyword,
        symbolName: String,
        tier: Int,
        description: String
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.symbolName = symbolName
        self.tier = tier
        self.description = description
    }
}

/// A keyword affinity talent tree consisting of 6 nodes organized in 3 tiers (2 nodes per tier).
public struct TalentTree: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        keyword.rawValue
    }

    public let keyword: Keyword
    public let nodes: [TalentNode]

    public init(keyword: Keyword, nodes: [TalentNode]) {
        self.keyword = keyword
        self.nodes = nodes
    }

    public func nodes(forTier tier: Int) -> [TalentNode] {
        nodes.filter { $0.tier == tier }
    }

    /// Evaluates whether a given node in this tree can be unlocked based on row-gated progression and available points.
    public func canUnlock(node: TalentNode, unlockedNodeIDs: Set<String>, availablePoints: Int) -> Bool {
        guard availablePoints > 0 else { return false }
        guard !unlockedNodeIDs.contains(node.id) else { return false }

        switch node.tier {
        case 1:
            return true
        case 2:
            // Row 2 requires all Tier 1 nodes in this tree to be unlocked.
            let tier1Nodes = nodes(forTier: 1)
            return tier1Nodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
        case 3:
            // Row 3 requires all Tier 2 nodes in this tree to be unlocked.
            let tier2Nodes = nodes(forTier: 2)
            return tier2Nodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
        default:
            return false
        }
    }

    /// Whether all nodes in the specified tier are unlocked.
    public func isTierComplete(_ tier: Int, unlockedNodeIDs: Set<String>) -> Bool {
        let tierNodes = nodes(forTier: tier)
        guard !tierNodes.isEmpty else { return false }
        return tierNodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
    }
}

/// Configuration defining the 3 keyword affinity trees for a specific combatant.
public struct CombatantTalentConfig: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        combatantID
    }

    public let combatantID: String
    public let trees: [TalentTree]

    public init(combatantID: String, trees: [TalentTree]) {
        self.combatantID = combatantID
        self.trees = trees
    }

    public func tree(for keyword: Keyword) -> TalentTree? {
        trees.first { $0.keyword == keyword }
    }

    public func node(matching id: String) -> TalentNode? {
        for tree in trees {
            if let node = tree.nodes.first(where: { $0.id == id }) {
                return node
            }
        }
        return nil
    }
}
