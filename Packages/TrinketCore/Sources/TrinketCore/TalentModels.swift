import Foundation

public struct TalentNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let keyword: Keyword
    public let row: Int
    public let iconID: String?
    public let description: String

    private enum CodingKeys: String, CodingKey {
        // symbolName is the persisted key; iconID is the in-memory name.
        // Never rename without a save migration.
        case id, name, keyword, row, description
        case iconID = "symbolName"
    }

    public init(
        id: String,
        name: String,
        keyword: Keyword,
        row: Int = 1,
        iconID: String? = nil,
        description: String,
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.row = row
        self.iconID = iconID
        self.description = description
    }
}

public struct TalentTree: Identifiable, Hashable, Codable, Sendable {
    /// Derived from name and keyword; renaming a tree changes its identity.
    /// Trees are tiny (single-digit nodes), so the linear scans below are intentional.
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

    public var rows: [Int] {
        Set(nodes.map(\.row)).sorted()
    }

    public func nodes(forRow row: Int) -> [TalentNode] {
        nodes.filter { $0.row == row }
    }

    public func canUnlock(node: TalentNode, unlockedNodeIDs: Set<String>, availablePoints: Int) -> Bool {
        guard availablePoints > 0 else { return false }
        guard let node = self.node(matching: node.id) else { return false }
        guard !unlockedNodeIDs.contains(node.id) else { return false }
        // Eligibility resolves the row from the owning tree, not the supplied node.
        if node.row == 1 {
            return true
        }
        guard node.row > 1 else {
            return false
        }
        return isRowComplete(node.row - 1, unlockedNodeIDs: unlockedNodeIDs)
    }

    public func isRowComplete(_ row: Int, unlockedNodeIDs: Set<String>) -> Bool {
        let rowNodes = nodes(forRow: row)
        guard !rowNodes.isEmpty else { return false }
        return rowNodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
    }

    public func node(matching id: String) -> TalentNode? {
        nodes.first { $0.id == id }
    }
}

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

    public func tree(matching id: String) -> TalentTree? {
        trees.first { $0.id == id }
    }

    public func node(matching id: String) -> TalentNode? {
        for tree in trees {
            if let node = tree.node(matching: id) {
                return node
            }
        }
        return nil
    }

    public func hasUnlockableNode(
        unlockedNodeIDs: Set<String>,
        availablePoints: Int,
    ) -> Bool {
        guard availablePoints > 0 else { return false }
        return trees.contains { tree in
            tree.nodes.contains { node in
                tree.canUnlock(
                    node: node,
                    unlockedNodeIDs: unlockedNodeIDs,
                    availablePoints: availablePoints,
                )
            }
        }
    }

    /// Repairs an over-budget or prerequisite-incomplete selection to the legal
    /// prefix: keeps prerequisite-complete selections in row, tree, then node order
    /// until the budget is spent. Removed selections leave their points available;
    /// valid selections within budget are unchanged. Gapped rows (missing prior row
    /// in the tree) stay locked, so chains through them are dropped.
    public func cappedUnlocks(_ nodeIDs: Set<String>, budget: Int) -> Set<String> {
        guard budget > 0 else { return [] }
        var kept: Set<String> = []
        let rows = Set(trees.flatMap(\.rows)).sorted()
        let maps = trees.map { Dictionary(grouping: $0.nodes, by: \.row) }
        for row in rows {
            for (tree, map) in zip(trees, maps) {
                guard let rowNodes = map[row] else { continue }
                for node in rowNodes {
                    guard nodeIDs.contains(node.id) else { continue }
                    let remaining = budget - kept.count
                    guard tree.canUnlock(
                        node: node,
                        unlockedNodeIDs: kept,
                        availablePoints: remaining,
                    ) else { continue }
                    kept.insert(node.id)
                    if kept.count == budget {
                        return kept
                    }
                }
            }
        }
        return kept
    }
}
