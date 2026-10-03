import Testing
import TrinketCore
@testable import TrinketContent

struct HomesteadCatalogTests {
    @Test func `every node has four increasing tiers`() {
        let nodes = GameContent.homesteadNodes
        #expect(Set(nodes.map(\.id)).count == nodes.count)
        for node in nodes {
            #expect(node.tiers.map(\.tier) == [1, 2, 3, 4])
            for tier in node.tiers {
                #expect(!tier.stageName.isEmpty)
                #expect(tier.stageName.split(separator: " ").count <= 3)
                #expect(Set(tier.production.map(\.resource)).count == tier.production.count)
            }
            for (lower, higher) in zip(node.tiers, node.tiers.dropFirst()) {
                let a = lower.combatBonus
                let b = higher.combatBonus
                for (oldModifiers, newModifiers) in [
                    (a.heroModifiers, b.heroModifiers), (a.companionModifiers, b.companionModifiers),
                ] {
                    #expect(oldModifiers.count == newModifiers.count)
                    for (old, new) in zip(oldModifiers, newModifiers) {
                        #expect(old.mapInt { _ in 0 }.mapPercent { _ in 0 } == new.mapInt { _ in 0 }.mapPercent { _ in 0 })
                        #expect(new.numericValue > old.numericValue)
                    }
                }
                for (old, new) in zip(
                    [a.astralChanceBonusPercent, a.goldFindPercent, a.experienceBonusPercent, a.gemsFindPercent],
                    [b.astralChanceBonusPercent, b.goldFindPercent, b.experienceBonusPercent, b.gemsFindPercent],
                ) where old > 0 {
                    #expect(new > old)
                }
                #expect(lower.production.map(\.resource) == higher.production.map(\.resource))
                for (old, new) in zip(lower.production, higher.production) {
                    #expect(new.quantity > old.quantity)
                }
            }
        }
    }

    @Test func `farms separate hero and companion health and crystal garden covers stone`() throws {
        let wheat = HomesteadEffects.from(nodeTiers: [.wheatField: 4])
        let coop = HomesteadEffects.from(nodeTiers: [.chickenCoop: 4])
        #expect(wheat.heroModifiers == [.maximumHealthPercent(0.4)])
        #expect(wheat.companionModifiers.isEmpty)
        #expect(coop.heroModifiers.isEmpty)
        #expect(coop.companionModifiers == [.maximumHealthPercent(0.4)])
        let crystal = try #require(GameContent.homesteadNode(matching: .crystalGarden)?.tier(4))
        #expect(crystal.combatBonus.heroModifiers == [.criticalDamagePercent(0.4)])
        #expect(crystal.production == [.init(.gems, 4), .init(.stone, 4)])
        let resources = Set(GameContent.homesteadNodes.flatMap { $0.tiers.flatMap { $0.production.map(\.resource) } })
        #expect(resources == Set(HomesteadResource.allCases))
    }

    @Test func `battle loot overrides receive the Gem bonus exactly once`() {
        let plan = BattleRewardPlan(
            stageGold: 10, goldFindPercent: 0, goldFindFlat: 4, gemsFindBonus: 4,
            heroExperience: 0, companionExperience: 0, materials: [.init(.gems, 1)], items: [],
        )
        #expect(plan.resolve(battleGold: .init()).materials == [.init(.gems, 5)])
        let override: [ResourceAmount] = [.init(.gems, 2), .init(.wood, 1)]
        let award = plan.resolve(battleGold: .init(), materials: override)
        #expect(award.materials == [.init(.gems, 6), .init(.wood, 1)])
        #expect(award.goldGained == 14)
        #expect(plan.resolve(battleGold: .init(), materials: override) == award)
    }

    @Test func `percentage rewards do not create absent rewards`() {
        let bonuses = HomesteadEffects.from(nodeTiers: [.wishingWell: 4, .library: 4, .moonlitSanctum: 4])
        #expect(bonuses.experienceBonusPercent == 20)
        #expect(bonuses.adjustedGold(100) == 120)
        #expect(bonuses.adjustedGold(0) == 0)
        #expect(bonuses.adjustedMaterials([.init(.gems, 2), .init(.gems, 3), .init(.wood, 1)]) == [
            .init(.gems, 3), .init(.gems, 3), .init(.wood, 1),
        ])
        #expect(bonuses.adjustedMaterials([.init(.wood, 1)]) == [.init(.wood, 1)])
    }

    @Test func `small reward fractions accumulate without previews consuming them`() {
        let plan = BattleRewardPlan(
            stageGold: 1, goldFindPercent: 5, gemsFindPercent: 5,
            heroExperience: 0, companionExperience: 0, materials: [.init(.gems, 1)], items: [],
        )
        var remainder = HomesteadRewardRemainders.zero
        var gold = 0
        var gems = 0
        for _ in 0 ..< 20 {
            let first = plan.resolve(battleGold: .init(), rewardRemainders: remainder)
            #expect(plan.resolve(battleGold: .init(), rewardRemainders: remainder) == first)
            gold += first.goldGained
            gems += first.materials.first?.quantity ?? 0
            remainder = first.rewardRemainders ?? .zero
        }
        #expect(gold == 21)
        #expect(gems == 21)
        #expect(remainder == .zero)
        let empty = plan.resolve(battleGold: .init(), materials: [], rewardRemainders: .init(gems: 95))
        #expect(empty.materials.isEmpty)
        #expect(empty.rewardRemainders?.gems == 95)
    }

    @Test func `Voyage completion preserves unpaid fractions without boosting them again`() {
        let plan = BattleRewardPlan(
            stageGold: 1, goldFindPercent: 5, gemsFindPercent: 5,
            heroExperience: 0, companionExperience: 0, materials: [.init(.gems, 1)], items: [],
            completionBonus: .init(gold: 50, materials: [.gems: 50]),
        )
        let award = plan.resolve(battleGold: .init())
        #expect(award.rewardRemainders == .init(gold: 5, gems: 5))
        #expect(award.goldGained == 11)
        #expect(award.materials == [.init(.gems, 11)])
    }
}
