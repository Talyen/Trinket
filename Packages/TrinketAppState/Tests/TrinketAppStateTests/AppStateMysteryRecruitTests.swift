import Foundation
import Testing
import TrinketBattleFeature
import TrinketContent
import TrinketFeatureSupport
import TrinketPersistence
import TrinketPersistenceTestSupport
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
        // Recruit resolution completes journey progress in the same transaction.
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))

        #expect(state.encounters.finishActiveMysteryEncounter())

        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.journey.activeStageID == "chapter-1-stage-3")
        #expect(!state.encounters.finishActiveMysteryEncounter())
    }

    @Test func recruitStagePreviewMatchesOpenedEncounter() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        let preview = try #require(state.journey.previewMysteryEvent(for: stage))
        #expect(preview.isRecruit)
        #expect(preview.id == "recruit-bear")
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.event.id == preview.id)
    }

    @Test func finishRevealWithoutDismissKeepsSessionForSeal() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)

        #expect(state.encounters.finishActiveMysteryEncounter(dismiss: false))
        #expect(state.encounters.activeMysteryEncounter != nil)
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))

        state.encounters.dismissActiveMysteryEncounter()
        #expect(state.encounters.activeMysteryEncounter == nil)
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

        let stage = try #require(GameContent.stage(id: "chapter-1-stage-5"))
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.event.isRecruit)
        #expect(session.event.unlockCombatantID != "ranger")
        #expect(session.unlockedCombatantID == session.event.unlockCombatantID)
    }

    @Test func journeyMysteryOpenMatchesSeededMapResolve() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        #expect(stage.encounter.mysteryEventID == nil)

        let pickContext = MysteryEventPickContext.journey(
            chapterNumber: stage.chapterNumber,
            inventory: state.playerSave.inventory,
            corruptionAltarCooldownRemaining: state.playerSave.currentSave
                .corruptionAltarCooldownRemaining
        )
        let expected = GameContent.resolveJourneyMysteryEvent(
            stage: stage,
            worldSeed: state.playerSave.worldSeed,
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
            worldSeed: state.playerSave.worldSeed,
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
    @Test func journeyMysteryPinFailureDoesNotOpenEncounter() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-4"))
        playerSave.forcesNextSaveFailure = true

        let message = state.journey.beginMysteryEncounter(for: stage)

        #expect(message != nil)
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(state.playerSave.journey.pinnedMysteryEventIDs[stage.id] == nil)
    }
    #endif

    @Test func staleChoiceIDFailsWithoutCompletingProgress() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = Stage(
            id: "audit-mystery-stale-choice",
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

        #expect(!state.encounters.resolveActiveMysteryChoice(choiceID: "stale-choice-id"))

        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.phase == .reading)
        #expect(session.persistFailureMessage == MysteryEncounterSession.choiceUnavailableMessage)
        #expect(!state.playerSave.journey.completedStageIDs.contains(stage.id))
        #expect(state.playerSave.roster.gold == goldBefore)
    }

    @Test func mysteryExperiencePreviewMatchesHeroAndCompanionAwards() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        var roster = state.playerSave.roster
        roster.progressions[roster.activeHeroID] = .at(level: 20)
        roster.progressions[roster.activeCompanionID] = .at(level: 5)
        state.playerSave.roster = roster

        let event = try #require(GameContent.mysteryEvent(matching: "overgrown-temple"))
        let session = attachMysterySession(event: event, to: state)
        session.installPreviews(save: state.playerSave.currentSave)

        let expectedHero = MysteryEffectApplier.experienceAward(
            for: roster.progression(for: roster.activeHero),
            highestLevel: roster.highestHeroLevel
        )
        let expectedCompanion = MysteryEffectApplier.experienceAward(
            for: roster.progression(for: roster.activeCompanion),
            highestLevel: roster.highestCompanionLevel
        )
        #expect(session.previewHeroExperienceAward == expectedHero)
        #expect(session.previewCompanionExperienceAward == expectedCompanion)
        #expect(expectedHero != expectedCompanion)
    }

    @Test func leaveChoiceDismissesEncounterAndCompletesProgress() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let event = try #require(GameContent.mysteryEvent(matching: GameContent.corruptionAltarEventID))
        attachMysterySession(event: event, to: state)

        #expect(state.encounters.resolveActiveMysteryChoice(choiceID: "leave"))
        #expect(state.encounters.activeMysteryEncounter == nil)
    }

    @Test func corruptChoiceWithNoEligibleItemsFailsWithBanner() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        state.playerSave.inventory = .freshStart
        let event = try #require(GameContent.mysteryEvent(matching: GameContent.corruptionAltarEventID))
        attachMysterySession(event: event, to: state)

        #expect(!state.encounters.resolveActiveMysteryChoice(choiceID: "corrupt-item"))

        let session = try #require(state.encounters.activeMysteryEncounter)
        #expect(session.phase == .reading)
        #expect(session.persistFailureMessage == MysteryEncounterSession.choiceUnavailableMessage)
        #expect(!state.playerSave.journey.completedStageIDs.contains(session.stage.id))
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

    @Test func recruitPersistFailureRollsBackUnlockAndProgressTogether() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))

        playerSave.forcesNextSaveFailure = true
        #expect(state.journey.handleStagePrimaryAction(for: stage) != nil)
        #expect(!state.playerSave.roster.isCompanionUnlocked("bear"))
        #expect(!state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.encounters.activeMysteryEncounter == nil)

        // One successful retry persists unlock + completion atomically.
        #expect(state.journey.handleStagePrimaryAction(for: stage) == nil)
        #expect(state.playerSave.roster.isCompanionUnlocked("bear"))
        #expect(state.playerSave.journey.completedStageIDs.contains("chapter-1-stage-2"))
        #expect(state.encounters.finishActiveMysteryEncounter())
    }

    @Test func finishActiveMysteryEncounterIgnoresReadingPhase() throws {
        let state = try context.makePlaySession(arguments: ["-reset-state"])
        let event = try #require(GameContent.mysteryEvent(matching: "hidden-cache"))
        let stage = Stage(
            id: "audit-mystery-reading-finish",
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

        #expect(!state.encounters.finishActiveMysteryEncounter())
        #expect(state.encounters.activeMysteryEncounter != nil)
        #expect(!state.playerSave.journey.completedStageIDs.contains(stage.id))
    }

    @Test func recruitAutoResolvePersistFailureReturnsMessage() throws {
        let playerSave = try SaveTestSupport.makeSaveStore(directoryURL: context.directoryURL)
        let state = try context.makePlaySession(arguments: ["-reset-state"], playerSave: playerSave)
        let stage = try #require(GameContent.stage(id: "chapter-1-stage-2"))
        playerSave.forcesNextSaveFailure = true

        let message = state.journey.handleStagePrimaryAction(for: stage)
        #expect(message != nil)
        #expect(state.encounters.activeMysteryEncounter == nil)
        #expect(!state.playerSave.roster.isCompanionUnlocked("bear"))
    }
    #endif

    @discardableResult
    private func attachMysterySession(
        event: MysteryEvent,
        to state: PlaySession
    ) -> MysteryEncounterSession {
        let stage = Stage(
            id: "audit-mystery-\(event.id)",
            chapterID: "chapter-1",
            chapterNumber: 1,
            stageNumber: 99,
            encounter: .mysteryEvent(eventID: event.id),
            rewards: .empty
        )
        let session = MysteryEncounterSession(
            origin: .journey(stage: stage),
            event: event,
            combatant: nil
        )
        state.encounters.activeMysteryEncounter = session
        return session
    }
}
