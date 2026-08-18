import Foundation

/// Unique identifier for a talent node in a combatant's talent tree.
public struct TalentNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let keyword: Keyword
    /// 1-indexed visual unlock row index: 1, 2, or 3 (UI progression gating only; power is flat across rows).
    public let row: Int

    public let description: String

    public init(
        id: String,
        name: String,
        keyword: Keyword,
        row: Int = 1,
        description: String
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.row = row
        self.description = description
    }
}

/// A named keyword affinity talent tree consisting of 6 nodes organized in 3 visual unlock rows (2 nodes per row).
public struct TalentTree: Identifiable, Hashable, Codable, Sendable {
    public var id: String {
        "\(name)_\(keyword.rawValue)"
    }

    public let name: String
    public let keyword: Keyword
    public let nodes: [TalentNode]

    public init(name: String? = nil, keyword: Keyword, nodes: [TalentNode]) {
        self.name = name ?? keyword.rawValue
        self.keyword = keyword
        self.nodes = nodes
    }

    public func nodes(forRow row: Int) -> [TalentNode] {
        nodes.filter { $0.row == row }
    }

    /// Evaluates whether a given node in this tree can be unlocked based on row-gated progression and available points.
    public func canUnlock(node: TalentNode, unlockedNodeIDs: Set<String>, availablePoints: Int) -> Bool {
        guard availablePoints > 0 else { return false }
        guard !unlockedNodeIDs.contains(node.id) else { return false }

        switch node.row {
        case 1:
            return true
        case 2:
            // Row 2 requires all Row 1 nodes in this tree to be unlocked.
            let row1Nodes = nodes(forRow: 1)
            return row1Nodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
        case 3:
            // Row 3 requires all Row 2 nodes in this tree to be unlocked.
            let row2Nodes = nodes(forRow: 2)
            return row2Nodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
        default:
            return false
        }
    }

    /// Whether all nodes in the specified unlock row are unlocked.
    public func isRowComplete(_ row: Int, unlockedNodeIDs: Set<String>) -> Bool {
        let rowNodes = nodes(forRow: row)
        guard !rowNodes.isEmpty else { return false }
        return rowNodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
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

    /// Keeps a row-legal prefix of `nodeIDs` that fits `budget`.
    public func cappedUnlocks(_ nodeIDs: Set<String>, budget: Int) -> Set<String> {
        guard nodeIDs.count > budget else { return nodeIDs }
        guard budget > 0 else { return [] }
        var kept: Set<String> = []
        for row in 1 ... 3 {
            for tree in trees {
                for node in tree.nodes(forRow: row) {
                    guard nodeIDs.contains(node.id), kept.count < budget else { continue }
                    let remaining = budget - kept.count
                    guard tree.canUnlock(
                        node: node,
                        unlockedNodeIDs: kept,
                        availablePoints: remaining
                    ) else { continue }
                    kept.insert(node.id)
                }
            }
        }
        return kept
    }
}
