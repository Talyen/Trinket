import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@Suite("AppStateSpires")
@MainActor
struct AppStateSpiresTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func startSpireBattleSucceedsForFreshAndAttunedParties() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.spires.startBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey)
        #expect(state.battle.activeBattle?.enemy != nil)
        #expect(state.battlePresentation(for: state.battle.activeBattle?.runKey)?.pendingRewardItem != nil)
    }

    @Test func startSpireBattleRequiresAttunement() throws {
        let state = try context.makePlaySession()
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let whelp = try #require(GameContent.companions.first { $0.id == "frost_whelp" })
        var roster = state.playerSave.roster
        roster.unlockedHeroIDs.insert(rogue.id)
        roster.unlockedCompanionIDs.insert(whelp.id)
        roster.activeHeroID = rogue.id
        roster.activeCompanionID = whelp.id
        state.playerSave.roster = roster

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.spires.startBattle(for: floor)
        #expect(message?.title == "Not Attuned")
        #expect(state.battle.activeBattle == nil)
    }

    @Test func startSpireBattleAllowsNonIronSpireAtFreshProgress() throws {
        let spire = try #require(GameContent.spire(id: .cinderSpire))
        let hero = try #require(GameContent.heroes.first { $0.keywordProfile.contains(spire.keyword) })
        let companion = try #require(
            GameContent.companions.first { $0.keywordProfile.contains(spire.keyword) }
        )
        let state = try context.makePlaySession()
        var roster = state.playerSave.roster
        roster.unlockedHeroIDs.insert(hero.id)
        roster.unlockedCompanionIDs.insert(companion.id)
        roster.activeHeroID = hero.id
        roster.activeCompanionID = companion.id
        state.playerSave.roster = roster

        let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: spire.id, floor: 1).runKey)
    }

    @Test func startSpireBattleRejectsLockedAndClearedFloors() throws {
        let state = try context.makePlaySession()
        let hero = state.playerSave.roster.activeHero
        let companion = state.playerSave.roster.activeCompanion

        for floor in 1 ... 2 {
            let spireFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: floor))
            state.spires.completeFloor(
                spireFloor,
                hero: hero,
                companion: companion
            )
        }

        let clearedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: clearedFloor)?.title == "Floor Cleared")

        let lockedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 4))
        #expect(state.spires.startBattle(for: lockedFloor)?.title == "Floor Locked")
    }

    @Test func startSpireBattlePreviewsFloorRewardItem() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        #expect(state.battlePresentation(for: state.battle.activeBattle?.runKey)?.pendingRewardItem != nil)
    }
}
