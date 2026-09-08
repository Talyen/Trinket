import Testing
import TrinketContent
import TrinketPersistence
@testable import TrinketAppState

@Suite("Mode content boundaries")
struct ContentAccessModeTests {
    @Test @MainActor
    func `campaign and spire preparation cannot bypass payment`() throws {
        let context = try AppTestContext()
        let state = try context.makeAppState()
        let store = state.playerSave
        store.contentAccess = .free
        let stage = try #require(GameContent.stage(id: "chapter-4-stage-1"))
        #expect(state.play.journey.handleStagePrimaryAction(for: stage)?.fullGameOffer == .campaign(chapter: 4))
        state.play.journey.prepareBattle(for: stage)
        #expect(!state.play.battle.hasPreparedRun(PlayBattleOrigin.journey(stageID: stage.id).runKey))
        let floor = try #require(GameContent.spireFloor(spireID: .ironVein, floor: 11))
        #expect(state.play.spires.startBattle(for: floor)?.fullGameOffer == .spire(.ironVein, floor: 11))
        state.play.spires.prepareBattle(for: floor)
        #expect(!state.play.battle.hasPreparedRun(PlayBattleOrigin.spire(spireID: .ironVein, floor: 11).runKey))
        #expect(store.accessRestriction(for: .journey(stageID: "chapter-3-stage-1")) == nil)
        #expect(store.accessRestriction(for: .spire(spireID: .ironVein, floor: 10)) == nil)
        store.contentAccess = .fullGame
        #expect(store.accessRestriction(for: .journey(stageID: stage.id)) == nil)
        #expect(store.accessRestriction(for: .spire(spireID: .ironVein, floor: 11)) == nil)
    }

    @Test @MainActor
    func `saved labyrinth continuation is preserved but not playable for free`() throws {
        let context = try AppTestContext()
        let state = try context.makeAppState()
        let store = state.playerSave
        #expect(state.play.labyrinth.enter() == nil)
        #expect(store.persistBatch(logging: "Test deep map") { save in
            for _ in 1 ... 3 {
                let floor = save.labyrinth.currentFloorNumber
                if let boss = save.labyrinth.nodes.values.first(where: {
                    $0.type.canonical == .boss && save.labyrinth.cluster(for: $0.id)?.depthBand == floor
                }) {
                    save.labyrinth.markCleared(nodeID: boss.id)
                }
            }
        })
        let node = try #require(store.labyrinth.nodes.values.first {
            store.labyrinth.cluster(for: $0.id)?.depthBand == 4 && $0.type.isCombat
        })
        let savedMap = store.labyrinth
        store.contentAccess = .free
        #expect(state.play.labyrinth.handleNodeAction(nodeID: node.id)?.fullGameOffer == .labyrinth(floor: 4))
        state.play.labyrinth.prepareReachableBattles()
        #expect(!state.play.battle.hasPreparedRun(PlayBattleOrigin.labyrinth(nodeID: node.id).runKey))
        #expect(store.labyrinth == savedMap)
        store.contentAccess = .fullGame
        #expect(store.accessRestriction(for: .labyrinth(nodeID: node.id)) == nil)
    }

    @Test @MainActor
    func `retry after access loss returns to the map`() throws {
        let context = try AppTestContext()
        let state = try context.makeAppState()
        try PlayBattleLaunchTestSupport.setActiveParty(heroID: "warlock", companionID: "phoenix", in: state.play)
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        #expect(state.play.journey.startBattle(for: stage) == nil)
        #expect(state.play.battle.activeBattle != nil)
        state.playerSave.contentAccess = .free
        let message = state.play.restartActiveBattle()
        #expect(message?.fullGameOffer == .combatant("warlock"))
        #expect(state.play.battle.activeBattle == nil)
    }
}
