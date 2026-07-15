import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
@testable import Trinket

struct HomesteadPresentationTests {
    private enum LifecycleCase {
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
        .completed
    ])
    func projectLifecycleExposesExpectedRowAndFooter(caseKind: LifecycleCase) throws {
        switch caseKind {
        case .lockedPrerequisite:
            let definition = try #require(GameContent.homesteadNode(matching: .herbGarden))
            let status = makeStatus(definition: definition, homestead: .freshStart)
            let firstTier = try #require(definition.tier(1))
            #expect(status.rowState == .prerequisiteLocked)
            #expect(status.overviewEffect == definition.tier(1)?.bonus)
            #expect(status.tierPathState(for: firstTier) == .locked)
            #expect(status.footerState == .action(title: "Build", enabled: false, reason: "Requires Wheat Field"))
        case .unbuiltAffordable:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            let status = makeStatus(
                definition: definition,
                homestead: PlayerHomesteadState(resources: [.wood: 10, .stone: 4], nodeTiers: [:])
            )
            #expect(status.rowState == .unbuilt(affordable: true))
            #expect(status.footerState == .action(title: "Build", enabled: true, reason: nil))
        case .unbuiltUnaffordable:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            let status = makeStatus(definition: definition, homestead: .freshStart)
            #expect(status.rowState == .unbuilt(affordable: false))
        case .built:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            let status = makeStatus(
                definition: definition,
                homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
            )
            #expect(status.rowState == .built)
            #expect(status.overviewEffect == definition.tier(1)?.bonus)
            #expect(status.overviewEffect != definition.tier(2)?.bonus)
        case .upgradeReady:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            let status = makeStatus(
                definition: definition,
                homestead: PlayerHomesteadState(
                    resources: [.wood: 18, .stone: 8],
                    nodeTiers: [.wheatField: 1]
                ),
                gold: 14
            )
            let secondTier = try #require(definition.tier(2))
            #expect(status.rowState == .upgradeReady)
            #expect(status.statusSymbolName == "arrowshape.up.fill")
            #expect(status.tierPathState(for: secondTier) == .next(affordable: true))
        case .upgradeNotReady:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            let status = makeStatus(
                definition: definition,
                homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
            )
            let secondTier = try #require(definition.tier(2))
            #expect(status.rowState == .built)
            #expect(status.tierPathState(for: secondTier) == .next(affordable: false))
        case .completed:
            let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
            let status = makeStatus(
                definition: definition,
                homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 3])
            )
            #expect(status.rowState == .completed)
            #expect(status.overviewEffect == definition.tier(3)?.bonus)
            #expect(status.footerState == .complete)
        }
    }

    @Test func tierPathMapsCurrentTiersZeroThroughThree() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        let tiers = try #require(definition.tiers.count == 3 ? definition.tiers : nil)

        let tierZero = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [.wood: 10, .stone: 4], nodeTiers: [:])
        )
        #expect(tierZero.tierPathState(for: tiers[0]) == .next(affordable: true))
        #expect(tierZero.tierPathState(for: tiers[1]) == .future)

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
    }

    @Test func tierPathConnectorsMatchStageSelectProgressFrontier() throws {
        let definition = try #require(GameContent.homesteadNode(matching: .wheatField))
        #expect(definition.tiers.count == 3)

        let mid = makeStatus(
            definition: definition,
            homestead: PlayerHomesteadState(resources: [:], nodeTiers: [.wheatField: 1])
        )
        let first = mid.tierPathConnectors(for: 0)
        let second = mid.tierPathConnectors(for: 1)
        let third = mid.tierPathConnectors(for: 2)

        #expect(first.before == nil)
        #expect(first.after == .progressed)
        #expect(second.before == .progressed)
        #expect(second.after == .future)
        #expect(third.before == .future)
        #expect(third.after == nil)
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
