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

    @Test func `start spire battle succeeds for fresh and attuned parties`() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let message = state.spires.startBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey)
        #expect(state.battle.activeBattle?.enemy != nil)
        #expect(state.battlePresentation(for: state.battle.activeBattle?.runKey)?.pendingRewardItem != nil)
    }

    @Test func `unchanged spire inputs reuse prepared battle`() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let battle = try #require(context.lastBattle)
        state.spires.prepareBattle(for: floor)
        let preparedRevision = battle.preparedBattlePresentationRevision

        state.spires.prepareBattle(for: floor)

        #expect(battle.preparedBattlePresentationRevision == preparedRevision)
        #expect(battle.lifecyclePhase == .prepared)
    }

    @Test func `start spire battle requires attunement`() throws {
        let state = try context.makePlaySession()
        try PlayBattleLaunchTestSupport.setActiveParty(heroID: "rogue", companionID: "frost_whelp", in: state)

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
}
