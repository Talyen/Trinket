import Observation
import Testing
import TrinketContent
@testable import TrinketAppState
@testable import TrinketPersistence

@MainActor
struct EncounterOpeningLifetimeTests {
    private enum Encounter: CaseIterable { case shop, mystery }

    @Test(arguments: Encounter.allCases)
    private func `pin publication cannot start a battle or another cover`(encounter: Encounter) async throws {
        let context = try AppTestContext()
        let play = try context.makePlaySession(arguments: ["-reset-state"])
        let battleStage = try #require(GameContent.chapters[0].stages.first)
        let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        let mysteryStage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        await confirmation("Pinning an encounter publishes its saved stock or event") { published in
            withObservationTracking {
                _ = play.playerSave.journey
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(play.journey.startBattle(for: battleStage) == nil)
                    #expect(play.battle.activeBattle == nil)
                    #expect(play.encounters.beginShopOrAutoComplete(origin: .journey(stage: shopStage)) == nil)
                    #expect(play.encounters.beginMysteryEncounter(
                        origin: .journey(stage: mysteryStage), forcedEventID: "hidden-cache",
                    ) == nil)
                    #expect(play.encounters.activeShopEncounter == nil)
                    #expect(play.encounters.activeMysteryEncounter == nil)
                    published()
                }
            }
            open(encounter, in: play, shopStage: shopStage, mysteryStage: mysteryStage)
        }
        #expect(play.battle.activeBattle == nil)
        switch encounter {
        case .shop:
            #expect(play.encounters.activeShopEncounter != nil)
            #expect(play.encounters.activeMysteryEncounter == nil)
        case .mystery:
            #expect(play.encounters.activeMysteryEncounter != nil)
            #expect(play.encounters.activeShopEncounter == nil)
        }
    }

    @Test(arguments: Encounter.allCases)
    private func `progress replacement during cover publication cannot install a stale session`(encounter: Encounter) async throws {
        let context = try AppTestContext()
        let app = try context.makeAppState(arguments: ["-reset-state"])
        let play = app.play
        let generation = play.playerSave.sessionGeneration
        let shopStage = try #require(GameContent.stage(id: "chapter-2-stage-8"))
        let mysteryStage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        await confirmation("The cover publishes after its pin is committed") { published in
            withObservationTracking {
                _ = play.encounters.activeShopEncounter
                _ = play.encounters.activeMysteryEncounter
            } onChange: {
                MainActor.assumeIsolated {
                    #expect(app.resetGameplayProgress())
                    published()
                }
            }
            open(encounter, in: play, shopStage: shopStage, mysteryStage: mysteryStage)
        }
        #expect(play.playerSave.sessionGeneration != generation)
        #expect(play.encounters.activeShopEncounter == nil)
        #expect(play.encounters.activeMysteryEncounter == nil)
        #expect(play.encounters.canBeginTransientEncounter)
    }

    private func open(_ encounter: Encounter, in play: PlaySession, shopStage: Stage, mysteryStage: Stage) {
        switch encounter {
        case .shop:
            #expect(play.encounters.beginShopOrAutoComplete(origin: .journey(stage: shopStage)) == nil)
        case .mystery:
            #expect(play.encounters.beginMysteryEncounter(
                origin: .journey(stage: mysteryStage), forcedEventID: "hidden-cache",
            ) == nil)
        }
    }
}
