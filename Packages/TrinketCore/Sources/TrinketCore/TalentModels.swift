import Foundation

public struct TalentNode: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let name: String
    public let keyword: Keyword
    public let row: Int
    public let symbolName: String?
    public let description: String

    public init(
        id: String,
        name: String,
        keyword: Keyword,
        row: Int = 1,
        symbolName: String? = nil,
        description: String,
    ) {
        self.id = id
        self.name = name
        self.keyword = keyword
        self.row = row
        self.symbolName = symbolName
        self.description = description
    }
}

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

    public func canUnlock(node: TalentNode, unlockedNodeIDs: Set<String>, availablePoints: Int) -> Bool {
        guard availablePoints > 0 else { return false }
        guard !unlockedNodeIDs.contains(node.id) else { return false }

        switch node.row {
        case 1:
            return true
        case 2:
            let row1Nodes = nodes(forRow: 1)
            return row1Nodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
        case 3:
            let row2Nodes = nodes(forRow: 2)
            return row2Nodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
        default:
            return false
        }
    }

    public func isRowComplete(_ row: Int, unlockedNodeIDs: Set<String>) -> Bool {
        let rowNodes = nodes(forRow: row)
        guard !rowNodes.isEmpty else { return false }
        return rowNodes.allSatisfy { unlockedNodeIDs.contains($0.id) }
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

    public func node(matching id: String) -> TalentNode? {
        for tree in trees {
            if let node = tree.nodes.first(where: { $0.id == id }) {
                return node
            }
        }
        return nil
    }

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
                        availablePoints: remaining,
                    ) else { continue }
                    kept.insert(node.id)
                }
            }
        }
        return kept
    }
}
