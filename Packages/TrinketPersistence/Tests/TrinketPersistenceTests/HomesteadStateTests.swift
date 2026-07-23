import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct HomesteadStateTests {
    private enum BuildSpendCase {
        case wheatFieldMaterials
        case herbGardenMaterials
    }

    @Test(arguments: [
        BuildSpendCase.wheatFieldMaterials,
        .herbGardenMaterials
    ])
    private func buildOrUpgradeSpendsRequiredCosts(caseKind: BuildSpendCase) throws {
        switch caseKind {
        case .wheatFieldMaterials:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            var homestead = PlayerHomesteadState(
                resources: [.wood: 20, .herbs: 10],
                nodeTiers: [:]
            )
            var roster = PlayerRosterState.freshStart
            roster.gold = 4

            let built = homestead.buildOrUpgrade(definition, roster: &roster)
            try #expect(built)
            try #expect(homestead.tier(for: .wheatField) == 1)
            try #expect(homestead.resources[.wood] == 15)
            try #expect(homestead.resources[.herbs] == 5)
            try #expect(roster.gold == 4)

        case .herbGardenMaterials:
            let definition = try #require(GameContent.homesteadNode(matching: .herbGarden))
            var homestead = PlayerHomesteadState(
                resources: [.wood: 5, .herbs: 5],
                nodeTiers: [.wheatField: 1]
            )
            var roster = PlayerRosterState.freshStart
            roster.gold = 10

            let built = homestead.buildOrUpgrade(definition, roster: &roster)
            try #expect(built)
            try #expect(homestead.tier(for: .herbGarden) == 1)
            try #expect(homestead.resources[.wood] == 0)
            try #expect(homestead.resources[.herbs] == 0)
            try #expect(roster.gold == 10)
        }
    }

    @Test func lockedNodeCannotUpgradeBeforePrerequisites() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .blacksmithForge))
        var homestead = PlayerHomesteadState(
            resources: [.wood: 100, .stone: 100, .iron: 100],
            nodeTiers: [.wheatField: 1]
        )
        var roster = PlayerRosterState.freshStart
        roster.gold = 100

        let built = homestead.buildOrUpgrade(definition, roster: &roster)
        try #expect(!built)
        try #expect(homestead.tier(for: .blacksmithForge) == 0)
    }

    @Test func effectsReplaceLowerTiersInsteadOfStacking() throws {
        let tier1 = HomesteadEffects.from(nodeTiers: [.wheatField: 1])
        let tier3 = HomesteadEffects.from(nodeTiers: [.wheatField: 3])

        try #expect(tier1.companionModifiers == [.maximumHealth(4)])
        try #expect(tier3.companionModifiers == [.maximumHealth(12)])
    }

    @Test func wishingWellIncreasesGoldFindPercent() throws {
        let effects = HomesteadEffects.from(nodeTiers: [.wishingWell: 2])
        try #expect(effects.goldFindPercent == 10)
        try #expect(effects.adjustedGold(100) == 110)
    }

    @Test func detectMagicIncreasesAstralChancePercent() throws {
        let effects = HomesteadEffects.from(nodeTiers: [.detectMagic: 3])
        try #expect(effects.astralChanceBonusPercent == 15)
    }

    @Test func grantCapsMaterialBalanceAtMax() throws {
        var homestead = PlayerHomesteadState(
            resources: [.wood: 995, .stone: PlayerHomesteadState.maxMaterialBalance],
            nodeTiers: [:]
        )

        homestead.grant([
            ResourceAmount(.wood, 10),
            ResourceAmount(.stone, 5),
            ResourceAmount(.food, 3)
        ])

        try #expect(homestead.resources[.wood] == PlayerHomesteadState.maxMaterialBalance)
        try #expect(homestead.resources[.stone] == PlayerHomesteadState.maxMaterialBalance)
        try #expect(homestead.resources[.food] == 3)
    }
}
