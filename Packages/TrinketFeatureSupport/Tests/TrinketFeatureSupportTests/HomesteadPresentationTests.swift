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
    func projectLifecycleExposesExpectedRowAndFooter(caseKind: LifecycleCase) throws {
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
        let firstTier = try #require(definition.tier(1))
        #expect(status.rowState == .prerequisiteLocked)
        #expect(status.overviewEffect == nil)
        #expect(status.overviewCaption == "Not Yet Constructed")
        #expect(status.tierPathState(for: firstTier) == .locked)
        #expect(status.footerState == .action(title: "Build", enabled: false, reason: "Requires Wheat Field"))
    }

    private func assertUnbuiltAffordableLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [.wood: 5, .herbs: 5], nodeTiers: [:])
        )
        #expect(status.rowState == .unbuilt(affordable: true))
        #expect(status.overviewEffect == nil)
        #expect(status.overviewCaption == "Not Yet Constructed")
        #expect(status.footerState == .action(title: "Build", enabled: true, reason: nil))
    }

    private func assertUnbuiltUnaffordableLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(definition: definition, homestead: .freshStart)
        #expect(status.rowState == .unbuilt(affordable: false))
        #expect(status.overviewEffect == nil)
        #expect(status.overviewCaption == "Not Yet Constructed")
    }

    private func assertBuiltLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
        )
        #expect(status.rowState == .built)
        let activeBonus = try #require(definition.tier(1)?.bonus)
        #expect(status.overviewEffect == activeBonus)
        #expect(status.overviewEffect != definition.tier(2)?.bonus)
        #expect(status.overviewCaption == activeBonus.description)
    }

    private func assertUpgradeReadyLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(
                resources: [.wood: 15, .herbs: 15],
                nodeTiers: [.wheatField: 1]
            ),
            gold: 14
        )
        let secondTier = try #require(definition.tier(2))
        #expect(status.rowState == .upgradeReady)
        #expect(status.statusSymbolName == "arrowshape.up.fill")
        #expect(status.tierPathState(for: secondTier) == .next(affordable: true))
    }

    private func assertUpgradeNotReadyLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
        )
        let secondTier = try #require(definition.tier(2))
        #expect(status.rowState == .built)
        #expect(status.tierPathState(for: secondTier) == .next(affordable: false))
    }

    private func assertCompletedLifecycle() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let status = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 4])
        )
        #expect(status.rowState == .completed)
        let activeBonus = try #require(definition.tier(4)?.bonus)
        #expect(status.overviewEffect == activeBonus)
        #expect(status.overviewCaption == activeBonus.description)
        #expect(status.footerState == .complete)
    }

    @Test func tierPathMapsCurrentTiersZeroThroughFour() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let tiers = try #require(definition.tiers.count == 4 ? definition.tiers : nil)

        let tierZero = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [.wood: 5, .herbs: 5], nodeTiers: [:])
        )
        #expect(tierZero.tierPathState(for: tiers[0]) == .next(affordable: true))
        #expect(tierZero.tierPathState(for: tiers[1]) == .future)
        #expect(tierZero.tierPathState(for: tiers[3]) == .future)

        let tierOne = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
        )
        #expect(tierOne.tierPathState(for: tiers[0]) == .completed)
        #expect(tierOne.tierPathState(for: tiers[1]) == .next(affordable: false))

        let tierTwo = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 2])
        )
        #expect(tierTwo.tierPathState(for: tiers[1]) == .completed)
        #expect(tierTwo.tierPathState(for: tiers[2]) == .next(affordable: false))

        let tierThree = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 3])
        )
        #expect(tierThree.tierPathState(for: tiers[2]) == .completed)
        #expect(tierThree.tierPathState(for: tiers[3]) == .next(affordable: false))

        let tierFour = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 4])
        )
        #expect(tierFour.tierPathState(for: tiers[3]) == .completed)
    }

    @Test func tierPathConnectorsMatchStageSelectProgressFrontier() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        #expect(definition.tiers.count == 4)

        let mid = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
        )
        let first = mid.tierPathConnectors(for: 0)
        let second = mid.tierPathConnectors(for: 1)
        let third = mid.tierPathConnectors(for: 2)
        let fourth = mid.tierPathConnectors(for: 3)

        #expect(first.before == nil)
        #expect(first.after == .progressed)
        #expect(second.before == .progressed)
        #expect(second.after == .future)
        #expect(third.before == .future)
        #expect(third.after == .future)
        #expect(fourth.before == .future)
        #expect(fourth.after == nil)

        let advanced = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 2])
        )
        let completed = advanced.tierPathConnectors(for: 1)
        let frontier = advanced.tierPathConnectors(for: 2)
        #expect(completed.before == .completed)
        #expect(completed.after == .progressed)
        #expect(frontier.before == .progressed)
    }

    private func makeStatus(
        definition: HomesteadNodeDefinition,
        homestead: PlayerHomesteadState,
        gold: Int = 0
    ) -> HomesteadProjectStatus {
        var roster = PlayerRosterState.freshStart
        roster.gold = gold
        return HomesteadProjectStatus(definition: definition, homestead: homestead, roster: roster)
    }
}
