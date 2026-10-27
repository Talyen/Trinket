import Foundation
import Testing
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

    @Test func `start spire battle succeeds for fresh parties`() throws {
        let state = try context.makePlaySession()
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        let selected = try #require(GameContent.spireModifier(for: floor, worldSeed: state.playerSave.worldSeed))
        state.spires.prepareBattle(for: floor)
        #expect(state.battleCoordinator.preparedRuns[PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey] != nil)
        let message = state.spires.startBattle(for: floor)
        #expect(message == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey)
        #expect(state.battle.activeBattle?.enemy != nil)
        #expect(state.battleCoordinator.registration(for: state.battle.activeBattle?.runKey)?.launch.inputs.launch.pendingRewardItem != nil)
        let presentation = try #require(state.battlePresentation(for: state.battle.activeBattle?.runKey))
        #expect(presentation.nodeModifiers.map(\.id) == [selected.id])
        let enemyModifiers = try #require(state.battle.activeBattle).enemyModifiers
        switch selected.effect {
        case let .damageDealt(keyword, amount):
            #expect(enemyModifiers.damageDealtBonus(for: keyword) == amount)
        case let .damageTakenReduction(keyword, percent):
            #expect(enemyModifiers.damageTakenReduction(for: keyword) == Double(percent) / 100)
        case .reward(.keyword):
            #expect(state.battleCoordinator.registration(for: state.battle.activeBattle?.runKey)?.launch.inputs.launch
                .pendingRewardItem != nil)
        default:
            Issue.record("Unexpected Spire modifier: \(selected.id.rawValue)")
        }
    }

    @Test func `spire preparation and launch allow a companion without the matching keyword`() throws {
        let state = try context.makePlaySession()
        try PlayBattleLaunchTestSupport.setActiveParty(heroID: "rogue", companionID: "phoenix", in: state)

        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 1))
        state.spires.prepareBattle(for: floor)
        #expect(state.battleCoordinator.preparedRuns[PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey] != nil)
        #expect(state.spires.startBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: .ironVein, floor: 1).runKey)
    }

    @Test func `start spire battle allows a party without either matching keyword`() throws {
        let spire = try #require(GameContent.spire(id: .cinderSpire))
        let state = try context.makePlaySession()
        try PlayBattleLaunchTestSupport.setActiveParty(heroID: "rogue", companionID: "bear", in: state)

        let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
        #expect(state.spires.startBattle(for: floor) == nil)
        #expect(state.battle.activeBattle?.runKey == PlayBattleOrigin.spire(spireID: spire.id, floor: 1).runKey)
    }

    @Test func `start spire battle rejects locked and cleared floors`() throws {
        let state = try context.makePlaySession()
        for floor in 1 ... 2 {
            let spireFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: floor))
            #expect(SpiresTestSupport.completeFloor(spireFloor, in: state))
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
        #expect(message?.title == PlayBattleCoordinator.activationFailureMessage.title)

        let lockedFloor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 2))
        #expect(state.spires.startBattle(for: lockedFloor)?.title == PlayBattleCoordinator.activationFailureMessage.title)
    }
}
