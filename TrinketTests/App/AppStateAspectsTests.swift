import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import Trinket

@MainActor
struct AppStateAspectsTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test(arguments: [
        (mode: "fresh", expectProgressionRewards: false),
        (mode: "attuned", expectProgressionRewards: true)
    ])
    func startAspectBattleSucceedsForFreshAndAttunedParties(
        mode: String,
        expectProgressionRewards: Bool
    ) throws {
        let state: AppState
        switch mode {
        case "fresh":
            state = try context.makeAppState(arguments: ["-reset-state"])
        case "attuned":
            state = try makeProgressedState()
            try attunePhysicalParty(on: state)
        default:
            Issue.record("Unexpected start mode \(mode)")
            return
        }

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.resumeToken == .aspect(aspectID: .ironVein, floor: 1))
        if expectProgressionRewards {
            #expect(state.battle.activeBattle?.hasProgressionRewards == true)
        }
    }

    @Test func startAspectBattleRequiresAttunement() throws {
        let state = try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5"
        ])
        // Seeded active companion is wolf (Poison/Physical). Pair with frost whelp to fail Physical.
        var roster = state.roster
        let frost = try #require(GameContent.companions.first { $0.id == "frost_whelp" })
        roster.setActiveCompanion(frost)
        state.roster = roster

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message?.title == "Not Attuned")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startAspectBattleAllowsNonIronAspectAtFreshProgress() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let aspect = try #require(GameContent.aspect(id: .cinderSpire))
        var roster = state.roster
        let hero = try #require(GameContent.heroes.first { $0.keywordProfile.contains(aspect.keyword) })
        let companion = try #require(
            GameContent.companions.first { $0.keywordProfile.contains(aspect.keyword) }
        )
        roster.unlock(hero)
        roster.unlock(companion)
        roster.setActiveHero(hero)
        roster.setActiveCompanion(companion)
        state.roster = roster

        let floor = try #require(GameContent.aspectFloor(aspectID: aspect.id, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.resumeToken == .aspect(aspectID: aspect.id, floor: 1))
    }

    @Test(arguments: [
        (floor: 3, clearFirst: false, expectedTitle: "Floor Locked"),
        (floor: 1, clearFirst: true, expectedTitle: "Floor Cleared")
    ])
    func startAspectBattleRejectsLockedAndClearedFloors(
        floor: Int,
        clearFirst: Bool,
        expectedTitle: String
    ) throws {
        let state = try makeProgressedState()
        try attunePhysicalParty(on: state)

        let aspectFloor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: floor))
        if clearFirst {
            state.completeAspectFloor(
                aspectFloor,
                hero: state.roster.activeHero,
                companion: state.roster.activeCompanion
            )
        }
        let message = state.startAspectBattle(for: aspectFloor)
        #expect(message?.title == expectedTitle)
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startAspectBattlePreviewsFloorRewardItem() throws {
        let state = try makeProgressedState()
        try attunePhysicalParty(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        let pending = try #require(state.battle.activeBattle?.pendingRewardItem)
        #expect(pending.baseType.keywordAffinities.contains(.physical))
    }

    private func makeProgressedState() throws -> AppState {
        try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5"
        ])
    }

    /// Iron Vein requires Physical on both hero and companion; knight/bear no longer qualify.
    private func attunePhysicalParty(on state: AppState) throws {
        var roster = state.roster
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let lizard = try #require(GameContent.companions.first { $0.id == "lizard_scout" })
        roster.unlock(rogue)
        roster.unlock(lizard)
        roster.setActiveHero(rogue)
        roster.setActiveCompanion(lizard)
        state.roster = roster
    }
}
