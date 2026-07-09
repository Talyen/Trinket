import Foundation
import Testing
import TrinketContent
import TrinketPersistence
import TrinketTestSupport
@testable import Trinket

@MainActor
struct AppStateMysteryRecruitTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func mysteryRecruitStageOpensEncounterAndUnlocksOnWelcome() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.roster.current.isPetUnlocked("wolf") == false)
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeMysteryEncounter)
        #expect(session.event.id == "recruit-wolf")
        #expect(session.combatant?.id == "wolf")
        #expect(session.phase == .reading)

        #expect(state.resolveActiveMysteryChoice(choiceID: "welcome"))
        #expect(state.roster.current.isPetUnlocked("wolf"))
        #expect(state.activeMysteryEncounter?.phase == .revealing)
        #expect(state.activeMysteryEncounter?.unlockedCombatantID == "wolf")
        // Opening / resolving a mystery does not advance journey progress.
        #expect(state.journey.current.activeStageID == "chapter-1-stage-1")

        state.finishActiveMysteryEncounter()

        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.current.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.journey.current.activeStageID == "chapter-1-stage-3")
    }

    @Test func alreadyUnlockedRecruitStageAutoCompletesWhenNoSubstitutesRemain() throws {
        let state = try context.makeAppState(arguments: ["-reset-state", "-seed-test-progress"])
        let completedStage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        #expect(state.persistStageCompletions(
            [completedStage],
            hero: state.roster.activeHero,
            pet: state.roster.activePet
        ) != nil)

        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.current.completedStageIDs.contains("chapter-1-stage-2"))
    }

    @Test func dismissMysteryEncounterDoesNotCompleteStage() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        _ = state.handleStagePrimaryAction(for: stage)
        #expect(state.activeMysteryEncounter != nil)

        state.dismissActiveMysteryEncounterWithoutCompleting()

        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.current.activeStageID == "chapter-1-stage-1")
        #expect(!state.journey.current.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.roster.current.isPetUnlocked("wolf") == false)
    }
}
