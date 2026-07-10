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

    @Test func startAspectBattleRequiresModesUnlock() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message?.title == "Modes Locked")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startAspectBattleRequiresAttunement() throws {
        let state = try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5,chapter-1-stage-6,chapter-1-stage-7,chapter-1-stage-8,chapter-1-stage-9,chapter-1-stage-10"
        ])
        // Seeded active pet is wolf (Nature/Physical). Pair with frost whelp to fail Physical.
        var roster = state.roster.current
        let frost = try #require(GameContent.pets.first { $0.id == "frost_whelp" })
        roster.setActivePet(frost)
        state.roster.current = roster

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message?.title == "Not Attuned")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startAspectBattleSucceedsWhenAttuned() throws {
        let state = try makeModesUnlockedState()
        try attunePhysicalParty(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.aspectBattle?.aspectID == .ironVein)
        #expect(state.battle.activeBattle?.aspectBattle?.floor == 1)
        #expect(state.battle.activeBattle?.hasProgressionRewards == true)
        #expect(state.battle.activeBattle?.resumeToken == .aspect(aspectID: .ironVein, floor: 1))
    }

    @Test func startAspectBattleRejectsLockedFloor() throws {
        let state = try makeModesUnlockedState()
        try attunePhysicalParty(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 3))
        let message = state.startAspectBattle(for: floor)
        #expect(message?.title == "Floor Locked")
    }

    @Test func startAspectBattleRejectsClearedFloor() throws {
        let state = try makeModesUnlockedState()
        try attunePhysicalParty(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        state.completeAspectFloor(floor, hero: state.roster.activeHero, pet: state.roster.activePet)
        let message = state.startAspectBattle(for: floor)
        #expect(message?.title == "Floor Cleared")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func completeAspectFloorAdvancesProgress() throws {
        let state = try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5,chapter-1-stage-6,chapter-1-stage-7,chapter-1-stage-8,chapter-1-stage-9,chapter-1-stage-10"
        ])
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = state.roster.activeHero
        let pet = state.roster.activePet

        state.completeAspectFloor(floor, hero: hero, pet: pet, battleEarnedGold: 2)
        #expect(state.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
    }

    @Test func endAspectBattleClearsLiveBattle() throws {
        let state = try makeModesUnlockedState()
        try attunePhysicalParty(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        state.battle.endBattle()
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startAspectBattlePreviewsFloorRewardItem() throws {
        let state = try makeModesUnlockedState()
        try attunePhysicalParty(on: state)

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        let pending = try #require(state.battle.activeBattle?.pendingRewardItem)
        #expect(pending.baseType.keywordAffinities.contains(.physical))
    }

    private func makeModesUnlockedState() throws -> AppState {
        try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5,chapter-1-stage-6,chapter-1-stage-7,chapter-1-stage-8,chapter-1-stage-9,chapter-1-stage-10"
        ])
    }

    /// Iron Vein requires Physical on both hero and pet; knight/bear no longer qualify.
    private func attunePhysicalParty(on state: AppState) throws {
        var roster = state.roster.current
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let lizard = try #require(GameContent.pets.first { $0.id == "lizard_scout" })
        roster.unlock(rogue)
        roster.unlock(lizard)
        roster.setActiveHero(rogue)
        roster.setActivePet(lizard)
        state.roster.current = roster
    }
}
