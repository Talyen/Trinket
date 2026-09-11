import Testing
import TrinketContent
import TrinketCore
import TrinketFeatureAdapters
import TrinketPersistence
@testable import TrinketFeatureSupport

struct HomesteadPresentationTests {
    enum LifecycleCase {
        case lockedPrerequisite
        case unbuiltAffordable
        case unbuiltUnaffordable
        case built
        case upgradeReady
        case upgradeNotReady
        case completed
    }

    @Test(arguments: [
        LifecycleCase.lockedPrerequisite,
        .unbuiltAffordable,
        .unbuiltUnaffordable,
        .built,
        .upgradeReady,
        .upgradeNotReady,
        .completed,
    ])
    func `project lifecycle exposes current benefits and next offer`(caseKind: LifecycleCase) throws {
        switch caseKind {
        case .lockedPrerequisite:
            try assertLockedPrerequisiteLifecycle()
        case .unbuiltAffordable:
            try assertUnbuiltAffordableLifecycle()
        case .unbuiltUnaffordable:
            try assertUnbuiltUnaffordableLifecycle()
        case .built:
            try assertBuiltLifecycle()
        case .upgradeReady:
            try assertUpgradeReadyLifecycle()
        case .upgradeNotReady:
            try assertUpgradeNotReadyLifecycle()
        case .completed:
            try assertCompletedLifecycle()
        }
    }

    private func assertLockedPrerequisiteLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .chickenCoop))
        let status = makeStatus(definition: definition, homestead: .freshStart)
        #expect(!status.isUnlocked)
        #expect(status.currentStage?.bonus == nil)
        #expect(!status.missingPrerequisites.isEmpty)
        #expect(!status.canBuildOrUpgrade)
    }

    private func assertUnbuiltAffordableLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [.wood: 5, .herbs: 5], nodeTiers: [:]),
        )
        #expect(status.currentTier == 0 && status.isAffordable)
        #expect(status.currentStage?.bonus == nil)
        #expect(status.canBuildOrUpgrade)
    }

    private func assertUnbuiltUnaffordableLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(definition: definition, homestead: .freshStart)
        #expect(status.currentTier == 0 && !status.isAffordable)
        #expect(status.currentStage?.bonus == nil)
    }

    private func assertBuiltLifecycle() throws {
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

    private func assertUpgradeReadyLifecycle() throws {
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
        #expect(status.canBuildOrUpgrade)
        #expect(status.nextTier == secondTier)
        #expect(status.canBuildOrUpgrade)
    }

    private func assertUpgradeNotReadyLifecycle() throws {
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

    private func assertCompletedLifecycle() throws {
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
            prerequisites: [],
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
        let definition = try #require(GameContent.homesteadNode(matching: .alchemyLab))
        let tier = try #require(definition.tier(3))
        let effects = HomesteadEffectLine.lines(for: tier)
        #expect(effects.map(\.displayValue) == ["+15%", "−30%"])
        #expect(effects[0].id != effects[1].id)
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
