import Testing
import TrinketCore
@testable import TrinketContent

struct HomesteadCatalogTests {
    @Test func `every node has four increasing tiers`() {
        let nodes = GameContent.homesteadNodes
        #expect(Set(nodes.map(\.id)).count == nodes.count)
        for node in nodes {
            #expect(node.maxTier == 4)
            #expect(node.tiers.map(\.tier) == [1, 2, 3, 4])
            for tier in node.tiers {
                #expect(!tier.stageName.isEmpty)
                #expect(tier.stageName.split(separator: " ").count <= 3)
                #expect(Set(tier.production.map(\.resource)).count == tier.production.count)
            }
            for (lower, higher) in zip(node.tiers, node.tiers.dropFirst()) {
                let a = lower.combatBonus
                let b = higher.combatBonus
                for (old, new) in zip(a.heroModifiers + a.companionModifiers, b.heroModifiers + b.companionModifiers) {
                    #expect(new.numericValue > old.numericValue)
                }
                for (old, new) in zip(
                    [a.astralChanceBonusPercent, a.goldFindFlat, a.experienceBonus, a.gemsFindBonus],
                    [b.astralChanceBonusPercent, b.goldFindFlat, b.experienceBonus, b.gemsFindBonus],
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
        #expect(wheat.heroModifiers == [.maximumHealth(16)])
        #expect(wheat.companionModifiers.isEmpty)
        #expect(coop.heroModifiers.isEmpty)
        #expect(coop.companionModifiers == [.maximumHealth(16)])
        let crystal = try #require(GameContent.homesteadNode(matching: .crystalGarden)?.tier(4))
        #expect(crystal.combatBonus.heroModifiers == [.criticalDamage(4)])
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

    @Test func `meta rewards are flat and do not create absent rewards`() {
        let bonuses = HomesteadEffects.from(nodeTiers: [.wishingWell: 4, .library: 4, .moonlitSanctum: 4])
        #expect(bonuses.experienceBonus == 20)
        #expect(bonuses.adjustedGold(100) == 104)
        #expect(bonuses.adjustedGold(0) == 0)
        #expect(bonuses.adjustedMaterials([.init(.gems, 2), .init(.gems, 3), .init(.wood, 1)]) == [
            .init(.gems, 6), .init(.gems, 3), .init(.wood, 1),
        ])
        #expect(bonuses.adjustedMaterials([.init(.wood, 1)]) == [.init(.wood, 1)])
    }
}
