import Testing
@testable import TrinketCore

struct TalentModelsTests {
    private func makeSampleTree(keyword: Keyword = .poison) -> TalentTree {
        let nodes: [TalentNode] = (1 ... 3).flatMap { row -> [TalentNode] in
            (1 ... 2).map { index in
                TalentNode(
                    id: "\(keyword.rawValue.lowercased())_r\(row)_\(index)",
                    name: "Talent \(row).\(index)",
                    keyword: keyword,
                    symbolName: "drop.fill",
                    row: row,
                    description: "Placeholder description for row \(row) node \(index)."
                )
            }
        }
        return TalentTree(keyword: keyword, nodes: nodes)
    }

    @Test func progressionCalculatesTalentPointsCorrectly() {
        let level1 = CombatantProgression.at(level: 1)
        #expect(level1.totalTalentPoints == 0)
        #expect(level1.availableTalentPoints(unlockedCount: 0) == 0)

        let level2 = CombatantProgression.at(level: 2)
        #expect(level2.totalTalentPoints == 1)
        #expect(level2.availableTalentPoints(unlockedCount: 0) == 1)
        #expect(level2.availableTalentPoints(unlockedCount: 1) == 0)

        let level10 = CombatantProgression.at(level: 10)
        #expect(level10.totalTalentPoints == 9)
        #expect(level10.availableTalentPoints(unlockedCount: 3) == 6)
    }

    @Test func tier1NodesCanBeUnlockedWithPoints() {
        let tree = makeSampleTree()
        let t1Node = tree.nodes(forTier: 1)[0]

        #expect(tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 1))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 0))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [t1Node.id], availablePoints: 1))
    }

    @Test func tier2NodesRequireAllTier1Nodes() {
        let tree = makeSampleTree()
        let t1Nodes = tree.nodes(forTier: 1)
        let t2Node = tree.nodes(forTier: 2)[0]

        // Partial Tier 1 (1/2) -> cannot unlock Tier 2
        let partialT1 = Set([t1Nodes[0].id])
        #expect(!tree.canUnlock(node: t2Node, unlockedNodeIDs: partialT1, availablePoints: 2))

        // Full Tier 1 (2/2) -> can unlock Tier 2
        let fullT1 = Set(t1Nodes.map(\.id))
        #expect(tree.isTierComplete(1, unlockedNodeIDs: fullT1))
        #expect(tree.canUnlock(node: t2Node, unlockedNodeIDs: fullT1, availablePoints: 1))
    }

    @Test func tier3NodesRequireAllTier2Nodes() {
        let tree = makeSampleTree()
        let t1Nodes = tree.nodes(forTier: 1)
        let t2Nodes = tree.nodes(forTier: 2)
        let t3Node = tree.nodes(forTier: 3)[0]

        let fullT1 = Set(t1Nodes.map(\.id))
        let partialT2 = fullT1.union([t2Nodes[0].id])
        #expect(!tree.canUnlock(node: t3Node, unlockedNodeIDs: partialT2, availablePoints: 2))

        let fullT1AndT2 = fullT1.union(t2Nodes.map(\.id))
        #expect(tree.isTierComplete(2, unlockedNodeIDs: fullT1AndT2))
        #expect(tree.canUnlock(node: t3Node, unlockedNodeIDs: fullT1AndT2, availablePoints: 1))
    }

    @Test func combatantConfigLooksUpNodesAndTrees() {
        let tree1 = makeSampleTree(keyword: .poison)
        let tree2 = makeSampleTree(keyword: .bleed)
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [tree1, tree2])

        #expect(config.tree(for: .poison)?.keyword == .poison)
        #expect(config.tree(for: .bleed)?.keyword == .bleed)
        #expect(config.tree(for: .holy) == nil)

        let targetNodeID = tree1.nodes[0].id
        #expect(config.node(matching: targetNodeID)?.name == tree1.nodes[0].name)
        #expect(config.node(matching: "non_existent") == nil)
    }
}
