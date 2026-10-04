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
        #expect(CombatantProgression.initial.availableTalentPoints(unlockedCount: 0) == 0)
        let level2 = CombatantProgression.at(level: 2)
        #expect(level2.availableTalentPoints(unlockedCount: 0) == 1)
        #expect(level2.availableTalentPoints(unlockedCount: 1) == 0)
        #expect(CombatantProgression.at(level: 3).availableTalentPoints(unlockedCount: 1) == 0)
        #expect(CombatantProgression.at(level: 10).availableTalentPoints(unlockedCount: 3) == 2)
        #expect(CombatantProgression.at(level: 40).totalTalentPoints == 20)
    }

    @Test func `available talent points clamp extreme counts without trapping`() {
        let level10 = CombatantProgression.at(level: 10)
        #expect(level10.availableTalentPoints(unlockedCount: Int.min) == 5)
        #expect(level10.availableTalentPoints(unlockedCount: -1) == 5)
        #expect(level10.availableTalentPoints(unlockedCount: Int.max) == 0)
    }

    @Test func `tier 1 nodes can be unlocked with points`() {
        let tree = makeSampleTree()
        let t1Node = tree.nodes(forRow: 1)[0]

        #expect(tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 1))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [], availablePoints: 0))
        #expect(!tree.canUnlock(node: t1Node, unlockedNodeIDs: [t1Node.id], availablePoints: 1))
    }

    @Test func `later talent rows require every node in the previous row`() {
        let tree = makeSampleTree()
        let previousNodes = tree.nodes(forRow: 3)
        let gatedNode = tree.nodes(forRow: 4)[0]
        let fullPrevious = Set(previousNodes.map(\.id))

        let partialPrevious = fullPrevious.subtracting([previousNodes[0].id])
        #expect(!tree.canUnlock(node: gatedNode, unlockedNodeIDs: partialPrevious, availablePoints: 2))

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

    @Test func `unlockable talents require unspent points and an eligible node`() {
        let tree1 = makeSampleTree(keyword: .poison)
        let tree2 = makeSampleTree(keyword: .bleed)
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [tree1, tree2])

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

    @Test func `config removes incomplete prerequisite chains even with spare points`() {
        let tree = makeSampleTree()
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [tree])
        let selected: Set<String> = [tree.nodes[0].id, tree.nodes[2].id, tree.nodes[3].id, tree.nodes[4].id, "unknown"]
        let kept = config.cappedUnlocks(selected, budget: 8)

        #expect(kept == [tree.nodes[0].id])
        #expect(config.cappedUnlocks(kept, budget: 8) == kept)
    }

    @Test func `config keeps legal row four talent when capping excess unlocks`() {
        let tree = makeSampleTree()
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [tree])
        let overBudget = Set(tree.nodes.map(\.id))

        #expect(config.cappedUnlocks(overBudget, budget: 7) == Set(tree.nodes.prefix(7).map(\.id)))
    }

    @Test func `capped unlocks follow tree array order`() {
        let poison = makeSampleTree(keyword: .poison)
        let bleed = makeSampleTree(keyword: .bleed)
        let reversed = CombatantTalentConfig(combatantID: "rogue", trees: [bleed, poison])
        let overBudget = Set(poison.nodes.map(\.id) + bleed.nodes.map(\.id))

        // The preceding budget test covers Poison first; reversing priority must select Bleed.
        #expect(reversed.cappedUnlocks(overBudget, budget: 1) == [bleed.nodes[0].id])
    }

    @Test func `duplicate node IDs across trees keep one copy`() {
        let shared = TalentNode(id: "shared", name: "Shared", keyword: .poison, row: 1, description: "Shared.")
        let first = TalentTree(keyword: .poison, nodes: [shared])
        let second = TalentTree(keyword: .bleed, nodes: [shared])
        let config = CombatantTalentConfig(combatantID: "rogue", trees: [first, second])
        #expect(config.cappedUnlocks(["shared"], budget: 2) == ["shared"])
    }
}
