import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
import TrinketTestSupport
@testable import TrinketAppState

@MainActor
struct AppStateMysteryRecruitTests {
    let context: AppTestContext

    init() throws {
        context = try AppTestContext()
    }

    @Test func mysteryRecruitStageOpensEncounterAndUnlocksOnWelcome() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.playerSave.roster.isCompanionUnlocked("bear") == false)
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.event.id == "recruit-bear")
        #expect(session.combatant?.id == "bear")
        #expect(session.phase == .revealing)
        #expect(session.unlockedCombatantID == "bear")
        #expect(state.playerSave.roster.isCompanionUnlocked("bear"))
        // Opening / resolving a mystery does not advance journey progress.
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-1")

        #expect(state.encounters.finishActiveMysteryEncounter())

        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-3")
        #expect(!state.encounters.finishActiveMysteryEncounter())
    }

    @Test func completedRosterTurnsRecruitStageIntoMystery() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state", "-seed-test-progress"])
        let completedStage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        #expect(state.journey.persistStageCompletions(
            [completedStage],
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion
        ))

        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(!session.event.isRecruit)
        #expect(!state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
    }

    @Test func unlockedAuthoredRecruitSubstitutesLockedCombatant() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        var roster = state.playerSave.roster
        roster.unlockedHeroIDs = [PlayerRosterState.starterHeroID, "ranger"]
        state.playerSave.roster = roster

        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.event.isRecruit)
        #expect(session.event.unlockCombatantID != "ranger")
        #expect(session.unlockedCombatantID == session.event.unlockCombatantID)
    }

    @Test func journeyMysteryOpenMatchesSeededMapResolve() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-5"))
        #expect(stage.encounter.mysteryEventID == nil)

        let pickContext = MysteryEventPickContext.journey(
            chapterNumber: stage.chapterNumber,
            inventory: state.playerSave.inventory,
            corruptionAltarCooldownRemaining: state.playerSave.currentSave
                .corruptionAltarCooldownRemaining
        )
        let expected = GameContent.resolveJourneyMysteryEvent(
            stage: stage,
            context: pickContext
        )

        #expect(state.journey.beginMysteryEncounter(for: stage) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.event.id == expected.id)
        #expect(!session.event.isRecruit)
        #expect(state.playerSave.journey.pinnedMysteryEventIDs[stage.id] == expected.id)

        // Pin wins over a different pick context on later resolve.
        let pinned = GameContent.resolveJourneyMysteryEvent(
            stage: stage,
            pinnedEventID: expected.id,
            context: .journey(
                chapterNumber: 2,
                inventory: state.playerSave.inventory,
                corruptionAltarCooldownRemaining: 0
            )
        )
        #expect(pinned.id == expected.id)
    }

    #if DEBUG
    @Test func resolveActiveMysteryChoiceRollsBackEffectsWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = Stage(
            id: "audit-mystery-gold",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .mysteryEvent(eventID: event.id),
            rewards: .empty
        )
        state.encounters.activeMysteryEncounter = MysteryEncounterSession(
            origin: .journey(stage: stage),
            event: event,
            combatant: nil
        )

        let goldBefore = state.playerSave.roster.gold
        playerSave.forcesNextSaveFailure = true
        #expect(!state.encounters.resolveActiveMysteryChoice(choiceID: "take-coinpurse"))
        #expect(state.encounters.activeMysteryEncounter != nil)
        #expect(state.encounters.activeMysteryEncounter?.persistFailureMessage != nil)
        #expect(state.playerSave.roster.gold == goldBefore)

        #expect(state.encounters.resolveActiveMysteryChoice(choiceID: "take-coinpurse"))
        #expect(state.encounters.activeMysteryEncounter?.phase == .reward)
        playerSave.forcesNextSaveFailure = true
        #expect(state.encounters.finishActiveMysteryEncounter())
        #expect(playerSave.forcesNextSaveFailure)
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.roster.gold == goldBefore + 20)
    }

    @Test func finishActiveMysteryEncounterKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.playerSave.roster.isCompanionUnlocked("bear"))
        #expect(state.encounters.activeMysteryEncounter?.phase == .revealing)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.encounters.finishActiveMysteryEncounter())
        #expect(state.encounters.activeMysteryEncounter != nil)
        #expect(state.encounters.activeMysteryEncounter?.persistFailureMessage != nil)
        #expect(!state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))

        #expect(state.encounters.finishActiveMysteryEncounter())
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
    }
    #endif
}
