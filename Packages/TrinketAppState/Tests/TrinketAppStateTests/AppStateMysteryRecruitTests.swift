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

        state.encounters.finishActiveMysteryEncounter()

        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-3")
    }

    @Test func completedRosterTurnsRecruitStageIntoMystery() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state", "-seed-test-progress"])
        let completedStage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        #expect(state.journey.persistStageCompletions(
            [completedStage],
            hero: state.playerSave.roster.activeHero,
            companion: state.playerSave.roster.activeCompanion
        ) != nil)

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

    @Test func dismissMysteryEncounterDoesNotCompleteStage() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        _ = state.journey.handleStagePrimaryAction(for: stage)
        #expect(state.encounters.activeMysteryEncounter != nil)

        state.encounters.dismissActiveMysteryEncounterWithoutCompleting()

        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-1")
        #expect(!state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.playerSave.roster.isCompanionUnlocked("bear"))
    }

    @Test func chooseItemPresentsCandidatesAndGrantsSelection() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let event = try #require(GameContent.mysteryEvent(matching: "abandoned-study"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        state.encounters.activeMysteryEncounter = MysteryEncounterSession(
            stage: stage,
            event: event,
            combatant: nil
        )

        let itemsBefore = state.playerSave.inventory.items.count
        #expect(state.encounters.resolveActiveMysteryChoice(choiceID: "search-scrolls"))

        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.phase == .choosingItem)
        #expect(session.itemCandidates.count == MysteryEffectApplier.chooseItemCandidateCount)
        #expect(!state.playerSave.journey.completedStageIDs.contains(stage.id))
        #expect(state.playerSave.inventory.items.count == itemsBefore)

        let chosen = try #require(session.itemCandidates.first)
        #expect(state.encounters.selectActiveMysteryItem(itemID: chosen.id))
        #expect(state.encounters.activeMysteryEncounter?.phase == .reward)
        #expect(state.encounters.finishActiveMysteryEncounter())
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.inventory.items.contains(where: { $0.id == chosen.id }))
        #expect(state.playerSave.inventory.items.count == itemsBefore + 1)
        #expect(state.playerSave.journey.completedStageIDs.contains(stage.id))
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
            stage: stage,
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

    @Test func selectActiveMysteryItemKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let event = try #require(GameContent.mysteryEvent(matching: "abandoned-study"))
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        state.encounters.activeMysteryEncounter = MysteryEncounterSession(
            stage: stage,
            event: event,
            combatant: nil
        )

        #expect(state.encounters.resolveActiveMysteryChoice(choiceID: "search-scrolls"))
        let chosen = try #require(state.encounters.activeMysteryEncounter?.itemCandidates.first)
        let itemsBefore = state.playerSave.inventory.items.count

        playerSave.forcesNextSaveFailure = true
        #expect(!state.encounters.selectActiveMysteryItem(itemID: chosen.id))
        #expect(state.encounters.activeMysteryEncounter != nil)
        #expect(state.encounters.activeMysteryEncounter?.phase == .choosingItem)
        #expect(state.encounters.activeMysteryEncounter?.persistFailureMessage != nil)
        #expect(state.playerSave.inventory.items.count == itemsBefore)
        #expect(!state.playerSave.journey.completedStageIDs.contains(stage.id))

        #expect(state.encounters.selectActiveMysteryItem(itemID: chosen.id))
        #expect(state.encounters.activeMysteryEncounter?.phase == .reward)
        #expect(state.encounters.finishActiveMysteryEncounter())
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.inventory.items.contains(where: { $0.id == chosen.id }))
        #expect(state.playerSave.journey.completedStageIDs.contains(stage.id))
    }
    #endif
}
