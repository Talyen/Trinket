import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureAdapters
import TrinketPersistence
@testable import TrinketFeatureSupport

struct HomesteadPresentationTests {
    @Test func `Blacksmith forge Astral bonus appears with tier benefits`() throws {
        let blacksmith = try #require(GameContent.homesteadNode(matching: .blacksmithForge))
        for tierNumber in 1 ... 4 {
            let tier = try #require(blacksmith.tier(tierNumber))
            let lines = HomesteadEffectLine.lines(for: tier, nodeID: .blacksmithForge)
            let bonus = lines.first { $0.id == .forgeAstralOdds }
            #expect(bonus?.displayValue == (tierNumber == 1 ? nil : "+\((tierNumber - 1) * 10)%"))
            #expect(bonus?.label == (tierNumber == 1 ? nil : "Forge Astral odds"))
        }
    }

    @Test func `independent unbuilt project can be built`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .blacksmithForge))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [.stone: 3, .iron: 7], nodeTiers: [:]),
        )
        #expect(status.currentTier == 0)
        #expect(status.currentStage?.bonus == nil)
        #expect(status.canBuildOrUpgrade)
    }

    @Test func `affordable unbuilt project can be built without active benefits`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [.wood: 5, .herbs: 5], nodeTiers: [:]),
        )
        #expect(status.currentTier == 0 && status.isAffordable)
        #expect(status.currentStage?.bonus == nil)
        #expect(status.canBuildOrUpgrade)
    }

    @Test func `unaffordable unbuilt project has no active benefits`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(definition: definition, homestead: .freshStart)
        #expect(status.currentTier == 0 && !status.isAffordable)
        #expect(status.currentStage?.bonus == nil)
    }

    @Test func `built project exposes its active benefits instead of the next tier`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1]),
        )
        #expect(status.currentTier > 0 && !status.isAffordable)
        let activeBonus = try #require(definition.tier(1)?.bonus)
        #expect(status.currentStage?.bonus == activeBonus)
        #expect(status.currentStage?.bonus != definition.tier(2)?.bonus)
    }

    @Test func `affordable upgrade exposes the next tier`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(
                resources: [.wood: 15, .herbs: 15],
                nodeTiers: [.wheatField: 1],
            ),
            gold: 14,
        )
        let secondTier = try #require(definition.tier(2))
        #expect(status.nextTier == secondTier)
        #expect(status.canBuildOrUpgrade)
    }

    @Test func `unaffordable upgrade exposes material shortfalls`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1]),
        )
        let secondTier = try #require(definition.tier(2))
        #expect(status.currentTier > 0 && !status.isAffordable)
        #expect(status.nextTier == secondTier)
        #expect(!status.canBuildOrUpgrade)
        #expect(status.materialShortfalls == secondTier.cost)
    }

    @Test func `completed project keeps its final benefits without another upgrade`() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 4]),
        )
        #expect(status.isComplete)
        let activeBonus = try #require(definition.tier(4)?.bonus)
        #expect(status.currentStage?.bonus == activeBonus)
        #expect(!status.canBuildOrUpgrade)
    }

    @Test func `ten tier project uses its actual completion boundary`() throws {
        let original = try #require(GameContent.homesteadNode(matching: .wheatField))
        let tiers = (1 ... 10).map { number in
            HomesteadNodeTier(
                tier: number,
                stageName: "Stage \(number)",
                cost: [.init(.wood, number)],
                bonus: .init(title: "Health", description: "Increase Health by \(number)"),
                combatBonus: .init(heroModifiers: [.maximumHealth(number)]),
            )
        }
        let definition = HomesteadNodeDefinition(
            id: original.id,
            title: original.title,
            summary: original.summary,
            iconID: original.iconID,
            category: original.category,
            tiers: tiers,
        )
        let before = makeStatus(
            definition: definition,
            homestead: .init(resources: [.wood: 10], nodeTiers: [.wheatField: 9]),
        )
        #expect(before.currentStage?.tier == 9)
        #expect(before.nextTier?.tier == 10)
        #expect(before.canBuildOrUpgrade)
        #expect(!before.isComplete)
        let after = makeStatus(
            definition: definition,
            homestead: .init(resources: [:], nodeTiers: [.wheatField: 10]),
        )
        #expect(after.isComplete)
        #expect(after.nextTier == nil)
        #expect(after.currentStage?.tier == 10)
    }

    @Test func `poison effects use resulting tier totals`() throws {
        let alchemy = try #require(GameContent.homesteadNode(matching: .alchemyLab))
        let alchemyTier = try #require(alchemy.tier(3))
        let alchemyEffects = HomesteadEffectLine.lines(for: alchemyTier)
        #expect(alchemyEffects.map(\.displayValue) == ["+20%", "+3"])

        let mycology = try #require(GameContent.homesteadNode(matching: .mycologyCellar))
        let mycologyTier = try #require(mycology.tier(3))
        let mycologyEffects = HomesteadEffectLine.lines(for: mycologyTier)
        #expect(mycologyEffects.map(\.displayValue) == ["+15%", "+3"])
    }

    @Test(arguments: GameContent.homesteadNodes)
    func `authored Homestead benefits render labeled effect lines`(node: HomesteadNodeDefinition) {
        for tier in node.tiers {
            let effects = HomesteadEffectLine.lines(for: tier, nodeID: node.id)
            #expect(!effects.isEmpty, "\(node.title) tier \(tier.tier)")
            for effect in effects {
                #expect(!effect.label.isEmpty)
                #expect(effect.displayValue.hasPrefix("+") || effect.displayValue.hasPrefix("−"))
            }
        }
    }

    @Test func `category progress accumulates built and total tiers in a single pass`() {
        let homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [.wheatField: 2, .chickenCoop: 1],
        )
        let progress = HomesteadCategoryProgress(category: .farming, homestead: homestead)
        #expect(progress.builtTiers == 3)
        #expect(progress.totalTiers > progress.builtTiers)
        #expect(progress.subtitle == "3 / \(progress.totalTiers)")
    }

    private func makeStatus(
        definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadState,
        gold: Int = 0,
    ) -> HomesteadProjectStatus {
        var roster = PlayerRosterState.freshStart
        roster.gold = gold
        return HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }
}
