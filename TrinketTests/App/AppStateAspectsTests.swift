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
        let state = try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5,chapter-1-stage-6,chapter-1-stage-7,chapter-1-stage-8,chapter-1-stage-9,chapter-1-stage-10"
        ])
        var roster = state.roster.current
        let bear = try #require(GameContent.pets.first { $0.id == "bear" })
        roster.setActivePet(bear)
        state.roster.current = roster

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.aspectBattle?.aspectID == .ironVein)
        #expect(state.battle.activeBattle?.aspectBattle?.floor == 1)
        #expect(state.battle.activeBattle?.hasProgressionRewards == true)
        #expect(state.activeBattleAspectID == AspectID.ironVein.rawValue)
        #expect(state.activeBattleAspectFloor == 1)
        #expect(state.activeBattleStageID == nil)
        #expect(state.isSavedBattleValid())
    }

    @Test func startAspectBattleRejectsLockedFloor() throws {
        let state = try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5,chapter-1-stage-6,chapter-1-stage-7,chapter-1-stage-8,chapter-1-stage-9,chapter-1-stage-10"
        ])
        var roster = state.roster.current
        let bear = try #require(GameContent.pets.first { $0.id == "bear" })
        roster.setActivePet(bear)
        state.roster.current = roster

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 3))
        let message = state.startAspectBattle(for: floor)
        #expect(message?.title == "Floor Locked")
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

    @Test func resumeSavedAspectBattleRestoresConfiguration() throws {
        let state = try context.makeAppState(arguments: [
            "-reset-state",
            "-seed-test-progress",
            "-completed-stages",
            "chapter-1-stage-1,chapter-1-stage-2,chapter-1-stage-3,chapter-1-stage-4,chapter-1-stage-5,chapter-1-stage-6,chapter-1-stage-7,chapter-1-stage-8,chapter-1-stage-9,chapter-1-stage-10"
        ])
        var roster = state.roster.current
        let bear = try #require(GameContent.pets.first { $0.id == "bear" })
        roster.setActivePet(bear)
        state.roster.current = roster

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        #expect(state.startAspectBattle(for: floor) == nil)
        state.battle.endBattle()
        #expect(state.activeBattleAspectID == nil)

        state.shellSession.setAspectBattleResume(aspectID: AspectID.ironVein.rawValue, floor: 1)
        #expect(state.isSavedBattleValid())
        state.resumeSavedBattle()
        #expect(state.battle.activeBattle?.aspectBattle?.aspectID == .ironVein)
        #expect(state.battle.activeBattle?.aspectBattle?.floor == 1)
    }
}
