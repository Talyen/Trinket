import Foundation
import Testing
import TrinketCore
@testable import TrinketContent

struct VoyageTests {
    @Test(arguments: VoyageDifficulty.allCases, [true, false])
    func `routes have regional enemies and bounded pacing`(difficulty: VoyageDifficulty, recruits: Bool) {
        for chapter in GameContent.chapters {
            for seed in UInt64(0) ..< 100 {
                let offer = VoyageOffer(id: "run", chapterID: chapter.id, difficulty: difficulty, seed: seed)
                let eligible = recruits ? ["recruit-bear"] : []
                let nodes = VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: eligible)
                #expect(nodes == VoyageGenerator.nodes(for: offer, eligibleRecruitEventIDs: eligible))
                #expect(nodes.count == difficulty.nodeCount)
                #expect(nodes.first?.type == .battle)
                #expect(nodes.last?.type == .boss)
                #expect(nodes.last?.enemyID == VoyageCatalog.bossID(chapterID: chapter.id))
                #expect(Set(nodes.map(\.id)).count == nodes.count)
                #expect(nodes.count(where: { $0.type == .shop }) == (difficulty == .hard ? 2 : 1))
                #expect(nodes.count(where: { $0.type == .recruit }) == (recruits ? 1 : 0))
                let battles = nodes.filter { $0.type == .battle }
                #expect(battles.count == (difficulty == .easy ? 3 : difficulty == .medium ? 4 : 5))
                #expect(Set(battles.prefix(4).compactMap(\.enemyID)).count == min(4, battles.count))
                for node in nodes {
                    if node.type == .battle {
                        #expect(VoyageCatalog.enemyIDs(chapterID: chapter.id).contains(node.enemyID ?? ""))
                        #expect(GameContent.enemy(matching: node.enemyID ?? "")?.isBoss == false)
                    }
                    #expect(node.modifierIDs.count == (node.type == .recruit ? 0 : 1))
                    for id in node.modifierIDs {
                        #expect(VoyageCatalog.modifiers(type: node.type, enemyID: node.enemyID).contains { $0.id == id })
                    }
                }
                for index in 1 ..< nodes.count {
                    let previous = nodes[index - 1]
                    let current = nodes[index]
                    if !current.type.isCombat {
                        #expect(current.type != previous.type)
                    }
                    if index > 1 {
                        #expect(!nodes[(index - 2) ... index].allSatisfy { $0.type == .battle })
                    }
                    if VoyageCatalog.modifiers(type: current.type, enemyID: current.enemyID).count > 1 {
                        #expect(current.modifierIDs.first != previous.modifierIDs.first || current.modifierIDs.isEmpty)
                    }
                }
                for index in 1 ..< battles.count {
                    #expect(battles[index].enemyID != battles[index - 1].enemyID)
                }
            }
        }
    }

    @Test func `completion bonus rounds once and is not multiplied again`() {
        let plan = BattleRewardPlan(
            stageGold: 10, goldFindPercent: 100, gemsFindBonus: 1, goldOverflowExperience: 5,
            heroExperience: 2, companionExperience: 2, materials: [ResourceAmount(.wood, 3), ResourceAmount(.gems, 1)], items: [],
            completionBonus: VoyageCompletionBonus(gold: 19, materials: [.wood: 9, .stone: 4, .gems: 4]),
        )
        let base = plan.resolve(battleGold: .init(gained: 2), includingCompletionBonus: false)
        let earned = plan.resolve(battleGold: .init(gained: 2))
        #expect(base.goldGained == 24)
        #expect(earned.goldGained == 32)
        #expect(earned.materials.first { $0.resource == .wood }?.quantity == 5)
        #expect(earned.materials.first { $0.resource == .gems }?.quantity == 3)
        #expect(!earned.materials.contains { $0.resource == .stone })
        let inputs = RewardSettlementInputs(
            gold: 99,
            reservedGold: 0,
            goldLimit: 100,
            heroProgression: .at(level: 5),
            companionProgression: .at(level: 5),
            productionDate: Date(),
        )
        let settled = plan.settle(battleGold: .init(gained: 2), inputs: inputs)
        #expect(settled.award.goldDelta == 1)
        #expect(settled.replacementExperience == 4)
        #expect(settled.award.materials == earned.materials)
        let defeat = plan.settleDefeat(progress: .init(remainingHealth: 0, maximumHealth: 100), inputs: inputs)
        #expect(defeat.award.goldGained == 0)
        #expect(defeat.award.materials.isEmpty)
    }

    @Test func `completion bonus saturates gold and material totals`() {
        let plan = BattleRewardPlan(
            stageGold: Int.max, goldFindPercent: 0,
            heroExperience: 0, companionExperience: 0,
            materials: [ResourceAmount(.wood, Int.max), ResourceAmount(.wood, 1)], items: [],
            completionBonus: VoyageCompletionBonus(gold: Int.max, materials: [.wood: Int.max]),
        )
        let award = plan.resolve(battleGold: .init())
        #expect(award.stageGold == Int.max)
        #expect(award.goldDelta == Int.max)
        #expect(award.goldGained == Int.max)
        #expect(award.materials == [ResourceAmount(.wood, Int.max)])
    }
}
