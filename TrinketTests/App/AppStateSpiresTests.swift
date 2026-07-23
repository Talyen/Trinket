import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistence
import TrinketTestSupport
@testable import Trinket

@Suite("AppStateSpires")
@MainActor
struct AppStateSpiresTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func startSpireBattleSucceedsForFreshAndAttunedParties() throws {
        let state = try context.makeAppState()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.startSpireBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.resumeToken == .spire(spireID: .ironVein, floor: 1))
        #expect(state.battle.activeBattle?.enemy != nil)
        #expect(state.battle.activeBattle?.pendingRewardItem != nil)
    }

    @Test func startSpireBattleRequiresAttunement() throws {
        let state = try context.makeAppState()
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let whelp = try #require(GameContent.companions.first { $0.id == "frost_whelp" })
        var roster = state.roster
        roster.unlockedHeroIDs.insert(rogue.id)
        roster.unlockedCompanionIDs.insert(whelp.id)
        roster.activeHeroID = rogue.id
        roster.activeCompanionID = whelp.id
        state.roster = roster

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.startSpireBattle(for: floor)
        #expect(message?.title == "Not Attuned")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startSpireBattleAllowsNonIronSpireAtFreshProgress() throws {
        let spire = try #require(GameContent.spire(id: .cinderSpire))
        let hero = try #require(GameContent.heroes.first { $0.keywordProfile.contains(spire.keyword) })
        let companion = try #require(
            GameContent.companions.first { $0.keywordProfile.contains(spire.keyword) }
        )
        let state = try context.makeAppState()
        var roster = state.roster
        roster.unlockedHeroIDs.insert(hero.id)
        roster.unlockedCompanionIDs.insert(companion.id)
        roster.activeHeroID = hero.id
        roster.activeCompanionID = companion.id
        state.roster = roster

        let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
        #expect(state.startSpireBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.resumeToken == .spire(spireID: spire.id, floor: 1))
    }

    @Test func startSpireBattleRejectsLockedAndClearedFloors() throws {
        let state = try context.makeAppState()
        let hero = state.roster.activeHero
        let companion = state.roster.activeCompanion

        for floor in 1 ... 2 {
            let spireFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: floor))
            state.completeSpireFloor(
                spireFloor,
                hero: hero,
                companion: companion
            )
        }

        let clearedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.startSpireBattle(for: clearedFloor)?.title == "Floor Cleared")

        let lockedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 4))
        #expect(state.startSpireBattle(for: lockedFloor)?.title == "Floor Locked")
    }

    @Test func startSpireBattlePreviewsFloorRewardItem() throws {
        let state = try context.makeAppState()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.startSpireBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.pendingRewardItem != nil)
    }
}
