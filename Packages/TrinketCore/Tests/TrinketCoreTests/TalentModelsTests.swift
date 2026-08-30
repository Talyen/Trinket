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
                    row: row,
                    description: "Placeholder description for row \(row) node \(index).",
                )
            }
        }
        return TalentTree(keyword: keyword, nodes: nodes)
    }

    @Test func `progression calculates talent points correctly`() {
        let level1 = CombatantProgression.at(level: 1)
        #expect(level1.totalTalentPoints == 0)
        #expect(level1.availableTalentPoints(unlockedCount: 0) == 0)

        let level2 = CombatantProgression.at(level: 2)
        #expect(level2.totalTalentPoints == 1)
        #expect(level2.availableTalentPoints(unlockedCount: 0) == 1)
        #expect(level2.availableTalentPoints(unlockedCount: 1) == 0)

        let level3 = CombatantProgression.at(level: 3)
        #expect(level3.totalTalentPoints == 1)

        let level10 = CombatantProgression.at(level: 10)
        #expect(level10.totalTalentPoints == 5)
        #expect(level10.availableTalentPoints(unlockedCount: 3) == 2)

        #expect(CombatantProgression.at(level: 20).totalTalentPoints == 10)
        #expect(CombatantProgression.at(level: 40).totalTalentPoints == 20)
    }

    @Test func `tier 1 nodes can be unlocked with points`() {
        let tree = makeSampleTree()
        let t1Node = tree.nodes(forRow: 1)[0]

        #expect(tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 1))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 0))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [t1Node.id], availablePoints: 1))
    }

    @Test(arguments: [1, 2])
    func `row N plus one requires all row N nodes unlocked`(row: Int) {
        let tree = makeSampleTree()
        let previousNodes = tree.nodes(forRow: row)
        let gatedNode = tree.nodes(forRow: row + 1)[0]
        let fullPrevious = Set(previousNodes.map(\.id))

        let partialPrevious = fullPrevious.subtracting([previousNodes[0].id])
        #expect(!tree.canUnlock(node: gatedNode, unlockedNodeIDs: partialPrevious, availablePoints: 2))

        #expect(tree.isRowComplete(row, unlockedNodeIDs: fullPrevious))
        #expect(tree.canUnlock(node: gatedNode, unlockedNodeIDs: fullPrevious, availablePoints: 1))
    }

    @Test func `combatant config looks up nodes and trees`() {
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

    @Test func `config caps over budget unlocks to row legal prefix`() {
        let poison = makeSampleTree(keyword: .poison)
        let bleed = makeSampleTree(keyword: .bleed)
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [poison, bleed])
        let overBudget = Set(poison.nodes.map(\.id) + bleed.nodes.map(\.id))

        #expect(config.cappedUnlocks(overBudget, budget: 0).isEmpty)
        #expect(config.cappedUnlocks(overBudget, budget: 1) == [poison.nodes[0].id])
        #expect(config.cappedUnlocks(Set([poison.nodes[0].id]), budget: 1) == [poison.nodes[0].id])
    }
}
