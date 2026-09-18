import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
@testable import TrinketAppState

@Suite("AppStateSpires")
@MainActor
struct AppStateSpiresTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func `start spire battle succeeds for fresh and attuned parties`() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.spires.startBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey)
        #expect(state.battle.activeBattle?.enemy != nil)
        #expect(state.battlePresentation(for: state.battle.activeBattle?.runKey)?.pendingRewardItem != nil)
    }

    @Test func `start spire battle requires attunement`() throws {
        let state = try context.makePlaySession()
        try PlayBattleLaunchTestSupport.setActiveParty(heroID: "rogue", companionID: "phoenix", in: state)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.spires.startBattle(for: floor)
        #expect(message != nil)
        #expect(state.battle.activeBattle == nil)
    }

    @Test func `start spire battle allows non iron spire at fresh progress`() throws {
        let spire = try #require(GameContent.spire(id: .cinderSpire))
        let hero = try #require(GameContent.heroes.first { $0.keywordProfile.contains(spire.keyword) })
        let companion = try #require(
            GameContent.companions.first { $0.keywordProfile.contains(spire.keyword) },
        )
        let state = try context.makePlaySession()
        try PlayBattleLaunchTestSupport.setActiveParty(heroID: hero.id, companionID: companion.id, in: state)

        let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: spire.id, floor: 1).runKey)
    }

    @Test func `start spire battle rejects locked and cleared floors`() throws {
        let state = try context.makePlaySession()
        let hero = state.playerSave.roster.activeHero
        let companion = state.playerSave.roster.activeCompanion

        for floor in 1 ... 2 {
            let spireFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: floor))
            state.spires.completeFloor(
                spireFloor,
                hero: hero,
                companion: companion,
            )
        }

        let clearedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: clearedFloor) != nil)

        let lockedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 4))
        #expect(state.spires.startBattle(for: lockedFloor) != nil)
    }

    @Test func `start spire battle returns failure message when battle already active`() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        #expect(state.battle.activeBattle != nil)

        let message = state.spires.startBattle(for: floor)
        #expect(message?.title == PlayBattleLaunch.activationFailureMessage.title)
    }

    @Test func `duplicate spire route delivery reports unavailable without paying twice`() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        let configuration = try #require(state.battle.activeBattle)
        let presentation = try #require(state.battlePresentation(for: configuration.runKey))
        let settlement = try #require(state.settleBattleRewards(configuration, battleGold: .init(gained: 0)))
        let loot = PlayBattleCompletion.preparedLoot(from: presentation, materialRewards: nil)
        let route = try #require(state.route(for: configuration.runKey))

        #expect(state.completeActiveBattle(configuration, battleGold: .init(gained: 0)).didComplete)
        let saveAfterVictory = state.playerSave.currentSave
        #expect(route.complete(configuration, presentation, settlement, nil, loot) == .unavailable)
        #expect(state.playerSave.currentSave == saveAfterVictory)
    }
}
