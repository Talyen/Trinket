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

    @Test func startAspectBattleRequiresAttunement() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])

        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let message = state.startAspectBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.aspectBattle?.aspectID == .ironVein)
        #expect(state.battle.activeBattle?.aspectBattle?.floor == 1)
        #expect(state.battle.activeBattle?.hasProgressionRewards == true)
    }

    @Test func completeAspectFloorAdvancesProgress() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let floor = try #require(GameContent.aspectFloor(aspectID: .ironVein, floor: 1))
        let hero = state.roster.activeHero
        let pet = state.roster.activePet

        state.completeAspectFloor(floor, hero: hero, pet: pet, battleEarnedGold: 2)
        #expect(state.aspects.highestClearedFloor(for: AspectID.ironVein.rawValue) == 1)
    }
}
