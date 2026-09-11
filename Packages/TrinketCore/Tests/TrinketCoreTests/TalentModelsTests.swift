import Foundation
import Testing
@testable import TrinketCore

struct TalentModelsTests {
    @Test(arguments: ["leaf.fill", "lucide:sword", nil] as [String?])
    func `talent icon preserves serialized symbol field`(iconID: String?) throws {
        var payload: [String: Any] = [
            "id": "legacy_talent",
            "name": "Legacy Talent",
            "keyword": "Thorns",
            "row": 1,
            "description": "Gain Thorns.",
        ]
        payload["symbolName"] = iconID
        let data = try JSONSerialization.data(withJSONObject: payload)
        let node = try JSONDecoder().decode(TalentNode.self, from: data)
        #expect(node.iconID == iconID)
        #expect(node.id == "legacy_talent")

        let encoded = try JSONEncoder().encode(node)
        let object = try JSONSerialization.jsonObject(with: encoded)
        let result = try #require(object as? [String: Any])
        #expect(result["symbolName"] as? String == iconID)
        #expect(result["iconID"] == nil)
    }

    private func makeSampleTree(keyword: Keyword = .poison) -> TalentTree {
        let nodes: [TalentNode] = (1 ... 4).flatMap { row -> [TalentNode] in
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
        #expect(CombatantProgression.at(level: 42).totalTalentPoints == 21)
        #expect(CombatantProgression.at(level: 44).totalTalentPoints == 22)
    }

    @Test func `tier 1 nodes can be unlocked with points`() {
        let tree = makeSampleTree()
        let t1Node = tree.nodes(forRow: 1)[0]

        #expect(tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 1))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 0))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [t1Node.id], availablePoints: 1))
    }

    @Test(arguments: [1, 2, 3])
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

    @Test func `tree rows are sorted and foreign nodes cannot unlock`() {
        let tree = makeSampleTree()
        let foreign = makeSampleTree(keyword: .bleed).nodes[0]

        #expect(tree.rows == [1, 2, 3, 4])
        #expect(!tree.canUnlock(node: foreign, unlockedNodeIDs: [], availablePoints: 1))
    }

    @Test func `eligibility uses the owning trees row for a matching node ID`() {
        let tree = makeSampleTree()
        let canonical = tree.nodes(forRow: 2)[0]
        let supplied = TalentNode(
            id: canonical.id,
            name: canonical.name,
            keyword: canonical.keyword,
            row: 1,
            description: canonical.description,
        )
        #expect(!tree.canUnlock(node: supplied, unlockedNodeIDs: [], availablePoints: 1))
        let prerequisites = Set(tree.nodes(forRow: 1).map(\.id))
        #expect(tree.canUnlock(node: supplied, unlockedNodeIDs: prerequisites, availablePoints: 1))
    }

    @Test func `row zero and gapped rows stay locked`() {
        let rowZero = TalentNode(
            id: "row_zero",
            name: "Row Zero",
            keyword: .poison,
            row: 0,
            description: "Placeholder description for row zero.",
        )
        let tree = TalentTree(keyword: .poison, nodes: [rowZero])
        #expect(!tree.canUnlock(node: rowZero, unlockedNodeIDs: [], availablePoints: 1))
        #expect(!tree.isRowComplete(0, unlockedNodeIDs: []))
        #expect(!tree.isRowComplete(99, unlockedNodeIDs: []))

        let gapped = TalentTree(
            keyword: .poison,
            nodes: [
                TalentNode(id: "g1", name: "G1", keyword: .poison, row: 1, description: "G1."),
                TalentNode(id: "g3", name: "G3", keyword: .poison, row: 3, description: "G3."),
            ],
        )
        let rowThree = gapped.nodes(forRow: 3)[0]
        #expect(!gapped.canUnlock(node: rowThree, unlockedNodeIDs: ["g1"], availablePoints: 1))
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

        #expect(config.hasUnlockableNode(unlockedNodeIDs: [], availablePoints: 1))
        #expect(!config.hasUnlockableNode(unlockedNodeIDs: [], availablePoints: 0))
        #expect(!config.hasUnlockableNode(
            unlockedNodeIDs: Set(tree1.nodes.map(\.id) + tree2.nodes.map(\.id)),
            availablePoints: 1,
        ))
    }

    @Test func `config caps over budget unlocks to row legal prefix`() {
        let poison = makeSampleTree(keyword: .poison)
        let bleed = makeSampleTree(keyword: .bleed)
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [poison, bleed])
        let overBudget = Set(poison.nodes.map(\.id) + bleed.nodes.map(\.id))

        #expect(config.cappedUnlocks(overBudget, budget: 0).isEmpty)
        #expect(config.cappedUnlocks(overBudget, budget: 1) == [poison.nodes[0].id])
        #expect(config.cappedUnlocks(overBudget, budget: 3) == Set(poison.nodes.prefix(2).map(\.id) + [bleed.nodes[0].id]))
        #expect(config.cappedUnlocks(overBudget, budget: overBudget.count) == overBudget)
        #expect(config.cappedUnlocks(Set([poison.nodes[0].id]), budget: 1) == [poison.nodes[0].id])
    }

    @Test(arguments: [1, 5, 8])
    func `config removes incomplete prerequisite chains at every budget`(budget: Int) {
        let tree = makeSampleTree()
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [tree])
        let selected: Set<String> = [tree.nodes[0].id, tree.nodes[2].id, tree.nodes[3].id, tree.nodes[4].id, "unknown"]
        let kept = config.cappedUnlocks(selected, budget: budget)

        #expect(kept == [tree.nodes[0].id])
        #expect(kept.isSubset(of: selected))
        #expect(kept.count <= budget)
        #expect(config.cappedUnlocks(kept, budget: budget) == kept)
    }

    @Test func `config keeps legal row four talent when capping excess unlocks`() {
        let tree = makeSampleTree()
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [tree])
        let overBudget = Set(tree.nodes.map(\.id))

        #expect(config.cappedUnlocks(overBudget, budget: 7) == Set(tree.nodes.prefix(7).map(\.id)))
    }
}
