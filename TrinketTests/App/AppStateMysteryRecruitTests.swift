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

        #expect(state.roster.isCompanionUnlocked("bear") == false)
        #expect(state.handleStagePrimaryAction(for: stage) == nil)

        let session = try #require(state.activeMysteryEncounter)
        #expect(session.event.id == "recruit-bear")
        #expect(session.combatant?.id == "bear")
        #expect(session.phase == .reading)

        #expect(state.resolveActiveMysteryChoice(choiceID: "welcome"))
        #expect(state.roster.isCompanionUnlocked("bear"))
        #expect(state.activeMysteryEncounter?.phase == .revealing)
        #expect(state.activeMysteryEncounter?.unlockedCombatantID == "bear")
        // Opening / resolving a mystery does not advance journey progress.
        #expect(state.journey.activeStageID == "chapter-1-stage-1")

        state.finishActiveMysteryEncounter()

        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.journey.activeStageID == "chapter-1-stage-3")
    }

    @Test func alreadyUnlockedRecruitStageAutoCompletesWhenNoSubstitutesRemain() throws {
        let state = try context.makeAppState(arguments: ["-reset-state", "-seed-test-progress"])
        let completedStage = try #require(GameContent.stage(id: "chapter-1-stage-1"))
        #expect(state.persistStageCompletions(
            [completedStage],
            hero: state.roster.activeHero,
            companion: state.roster.activeCompanion
        ) != nil)

        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        #expect(state.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.completedStageIDs.contains("chapter-1-stage-2"))
    }

    @Test func authoredRecruitEventDoesNotSubstituteAnotherCombatant() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        var roster = state.roster
        roster.unlockedHeroIDs = [PlayerRosterState.starterHeroID, "rogue"]
        state.roster = roster

        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(state.beginMysteryEncounter(for: stage) == nil)
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.completedStageIDs.contains(stage.id))
    }

    @Test func dismissMysteryEncounterDoesNotCompleteStage() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        _ = state.handleStagePrimaryAction(for: stage)
        #expect(state.activeMysteryEncounter != nil)

        state.dismissActiveMysteryEncounterWithoutCompleting()

        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.activeStageID == "chapter-1-stage-1")
        #expect(!state.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.roster.isCompanionUnlocked("bear") == false)
    }

    @Test func chooseItemPresentsCandidatesAndGrantsSelection() throws {
        let state = try context.makeAppState(arguments: ["-reset-state"])
        let event = try #require(GameContent.mysteryEvent(matching: "abandoned-study"))
        let stage = Stage(
            id: "audit-mystery-choose-item",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 98,
            flavorText: "Audit choose item.",
            encounter: .mysteryEvent(eventID: event.id),
            rewards: .empty
        )
        state.activeMysteryEncounter = MysteryEncounterSession(
            stage: stage,
            event: event,
            combatant: nil
        )

        let itemsBefore = state.inventory.items.count
        #expect(state.resolveActiveMysteryChoice(choiceID: "search-scrolls"))

        let session = try #require(state.activeMysteryEncounter)
        #expect(session.phase == .choosingItem)
        #expect(session.itemCandidates.count == MysteryEffectApplier.chooseItemCandidateCount)
        #expect(!state.journey.completedStageIDs.contains(stage.id))
        #expect(state.inventory.items.count == itemsBefore)

        let chosen = try #require(session.itemCandidates.first)
        #expect(state.selectActiveMysteryItem(itemID: chosen.id))
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.inventory.items.contains(where: { $0.id == chosen.id }))
        #expect(state.inventory.items.count == itemsBefore + 1)
        #expect(state.journey.completedStageIDs.contains(stage.id))
    }

    #if DEBUG
    @Test func resolveActiveMysteryChoiceRollsBackEffectsWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(arguments: ["-reset-state"], playerSave: playerSave)
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = Stage(
            id: "audit-mystery-gold",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            flavorText: "Audit mystery.",
            encounter: .mysteryEvent(eventID: event.id),
            rewards: .empty
        )
        state.activeMysteryEncounter = MysteryEncounterSession(
            stage: stage,
            event: event,
            combatant: nil
        )

        let goldBefore = state.roster.gold
        playerSave.forcesNextSaveFailure = true
        #expect(!state.resolveActiveMysteryChoice(choiceID: "take-coinpurse"))
        #expect(state.activeMysteryEncounter != nil)
        #expect(state.roster.gold == goldBefore)

        #expect(state.resolveActiveMysteryChoice(choiceID: "take-coinpurse"))
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.roster.gold == goldBefore + 20)
    }

    @Test func finishActiveMysteryEncounterKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        #expect(state.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.resolveActiveMysteryChoice(choiceID: "welcome"))
        #expect(state.roster.isCompanionUnlocked("bear"))
        #expect(state.activeMysteryEncounter?.phase == .revealing)

        playerSave.forcesNextSaveFailure = true
        #expect(!state.finishActiveMysteryEncounter())
        #expect(state.activeMysteryEncounter != nil)
        #expect(!state.journey.completedStageIDs.contains("chapter-1-stage-2"))

        #expect(state.finishActiveMysteryEncounter())
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.journey.completedStageIDs.contains("chapter-1-stage-2"))
    }

    @Test func selectActiveMysteryItemKeepsSessionOpenWhenPersistFails() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makeAppState(arguments: ["-reset-state"], playerSave: playerSave)
        let event = try #require(GameContent.mysteryEvent(matching: "abandoned-study"))
        let stage = Stage(
            id: "audit-mystery-choose-item-fail",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 97,
            flavorText: "Audit choose item persist fail.",
            encounter: .mysteryEvent(eventID: event.id),
            rewards: .empty
        )
        state.activeMysteryEncounter = MysteryEncounterSession(
            stage: stage,
            event: event,
            combatant: nil
        )

        #expect(state.resolveActiveMysteryChoice(choiceID: "search-scrolls"))
        let chosen = try #require(state.activeMysteryEncounter?.itemCandidates.first)
        let itemsBefore = state.inventory.items.count

        playerSave.forcesNextSaveFailure = true
        #expect(!state.selectActiveMysteryItem(itemID: chosen.id))
        #expect(state.activeMysteryEncounter != nil)
        #expect(state.activeMysteryEncounter?.phase == .choosingItem)
        #expect(state.inventory.items.count == itemsBefore)
        #expect(!state.journey.completedStageIDs.contains(stage.id))

        #expect(state.selectActiveMysteryItem(itemID: chosen.id))
        #expect(state.activeMysteryEncounter == nil)
        #expect(state.inventory.items.contains(where: { $0.id == chosen.id }))
        #expect(state.journey.completedStageIDs.contains(stage.id))
    }
    #endif
}
