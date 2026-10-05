import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeProgressRegressionTests {
    @Test @MainActor func `different choices at one Mystery count as one cooldown completion through reload`() throws {
        var base = PlayerSave.testSeed
        base.corruptionAltarCooldownRemaining = 6
        let stage = try #require(mysteryStages.first)
        let otherStage = try #require(mysteryStages.dropFirst().first)
        let event = try #require(GameContent.mysteryEvent(matching: "crystal-geode"))
        let encounter = EncounterIdentity(location: .journey(stageID: stage.id), save: base)
        var random = SeededRandomNumberGenerator(seed: 1)
        let offers = try MysteryOfferPersistence.prepare(event: event, encounter: encounter, save: &base, using: &random)
        #expect(offers.count == 2)
        let request = MysteryEncounterRequest(encounter: encounter, event: event, displayedOffers: offers)
        var first = base
        var second = base
        _ = try MysteryEncounterResolution.resolve(
            choiceID: offers[0].choiceID, request: request, save: &first, using: &random,
        ).get()
        _ = try MysteryEncounterResolution.resolve(
            choiceID: offers[1].choiceID, request: request, save: &second, using: &random,
        ).get()
        #expect(first.corruptionAltarCooldownRemaining == 5)
        #expect(second.corruptionAltarCooldownRemaining == 5)
        #expect(!CloudSaveMerge.hasDuplicateClaim(incoming: first, existing: second, base: base))
        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.corruptionAltarCooldownRemaining == 5)
        try claimMystery(stage: otherStage, save: &first)
        let advanced = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(advanced).currentSave
        #expect(reloaded.corruptionAltarCooldownRemaining == 4)
        #expect(reloaded.inventory.items.contains { $0.id == offers[0].item.id })
        #expect(reloaded.inventory.items.contains { $0.id == offers[1].item.id })
    }

    @Test @MainActor func `an altar reset equal to the shared cooldown survives another Mystery and reload`() throws {
        var base = PlayerSave.testSeed
        base.corruptionAltarCooldownRemaining = PlayerSave.corruptionAltarCooldownAfterEncounter
        base.modifiedAt = Date(timeIntervalSince1970: 1)
        let altarStage = try #require(mysteryStages.first)
        let otherStage = try #require(mysteryStages.dropFirst().first)
        let event = try #require(GameContent.mysteryEvent(matching: GameContent.corruptionAltarEventID))
        let leave = try #require(event.choices.first { $0.effects.contains(.leave) })
        #expect(MysteryEventPinApplier.pinJourneyEvent(stageID: altarStage.id, eventID: event.id, save: &base))
        var reset = base
        let request = MysteryEncounterRequest(
            encounter: EncounterIdentity(location: .journey(stageID: altarStage.id), save: reset),
            event: event, displayedOffers: [],
        )
        var random = SeededRandomNumberGenerator(seed: 1)
        #expect(try MysteryEncounterResolution.resolve(
            choiceID: leave.id, request: request, save: &reset, using: &random,
        ).get() == .dismiss)
        reset.modifiedAt = Date(timeIntervalSince1970: 3)
        var progressed = base
        try claimMystery(stage: otherStage, save: &progressed)
        progressed.modifiedAt = Date(timeIntervalSince1970: 2)
        #expect(reset.corruptionAltarCooldownRemaining == base.corruptionAltarCooldownRemaining)
        #expect(progressed.corruptionAltarCooldownRemaining == base.corruptionAltarCooldownRemaining - 1)
        let merged = CloudSaveMerge.merge(incoming: reset, existing: progressed, base: base, preferIncoming: false)
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(merged).currentSave
        #expect(reloaded.corruptionAltarCooldownRemaining == PlayerSave.corruptionAltarCooldownAfterEncounter)
        #expect(reloaded.journey.claimedRewardStageIDs.isSuperset(of: [altarStage.id, otherStage.id]))
    }

    @Test @MainActor func `an altar in a newly entered Labyrinth preserves its reset through reload`() throws {
        var base = PlayerSave.testSeed
        base.corruptionAltarCooldownRemaining = PlayerSave.corruptionAltarCooldownAfterEncounter
        #expect(!base.labyrinth.hasMap)
        var reset = base
        reset.labyrinth.ensureMap(seed: base.worldSeed)
        let node = try #require(reset.labyrinth.nodes.values.first { $0.type == .mystery })
        #expect(MysteryEventPinApplier.pinLabyrinthEvent(
            nodeID: node.id, eventID: GameContent.corruptionAltarEventID, save: &reset,
        ))
        reset.labyrinth.markCleared(nodeID: node.id)
        ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &reset)
        reset.modifiedAt = base.modifiedAt.addingTimeInterval(2)
        var progressed = base
        try claimMystery(stage: #require(mysteryStages.first), save: &progressed)
        progressed.modifiedAt = base.modifiedAt.addingTimeInterval(1)

        let merged = CloudSaveMerge.merge(incoming: reset, existing: progressed, base: base, preferIncoming: false)
        let context = try PersistenceTestContext()
        let reloaded = try context.seedAndReload(merged).currentSave
        #expect(reloaded.corruptionAltarCooldownRemaining == PlayerSave.corruptionAltarCooldownAfterEncounter)
        #expect(reloaded.labyrinth.nodes[node.id]?.isCleared == true)
        #expect(reloaded.labyrinth.nodes[node.id]?.mysteryEventID == GameContent.corruptionAltarEventID)
    }

    @Test(arguments: [1, 6], [true, false])
    func `independent Mystery completions both advance the altar cooldown`(
        cooldown: Int, preferIncoming: Bool,
    ) throws {
        var base = PlayerSave.testSeed
        base.corruptionAltarCooldownRemaining = cooldown
        let stages = mysteryStages
        let firstStage = try #require(stages.first)
        let secondStage = try #require(stages.dropFirst().first)
        var first = base
        var second = base
        try claimMystery(stage: firstStage, save: &first)
        try claimMystery(stage: secondStage, save: &second)
        #expect(first.corruptionAltarCooldownRemaining == cooldown - 1)
        #expect(second.corruptionAltarCooldownRemaining == cooldown - 1)
        #expect(first.journey.claimedRewardStageIDs == [firstStage.id])
        #expect(second.journey.claimedRewardStageIDs == [secondStage.id])
        #expect(!CloudSaveMerge.hasDuplicateClaim(incoming: first, existing: second, base: base))

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: preferIncoming)
        let restored = try snapshotRoundTrip(merged)
        #expect(restored.corruptionAltarCooldownRemaining == max(0, cooldown - 2))
        #expect(restored.journey.claimedRewardStageIDs == [firstStage.id, secondStage.id])
    }

    @Test func `a duplicated Mystery advances the cooldown once and a later altar resets it`() throws {
        var base = PlayerSave.testSeed
        base.corruptionAltarCooldownRemaining = 3
        let stage = try #require(mysteryStages.first)
        var first = base
        var second = base
        try claimMystery(stage: stage, save: &first)
        try claimMystery(stage: stage, save: &second)
        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.corruptionAltarCooldownRemaining == 2)

        ItemCorruptionApplier.recordCorruptionAltarEncounter(save: &second)
        second.modifiedAt = first.modifiedAt.addingTimeInterval(1)
        let reset = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(reset.corruptionAltarCooldownRemaining == PlayerSave.corruptionAltarCooldownAfterEncounter)
    }

    @Test(arguments: [true, false])
    @MainActor func `independently recruited combatants keep both XP awards after disk reload`(preferIncoming: Bool) throws {
        var base = PlayerSave.fresh
        base.starterSelection = .complete
        base.corruptionAltarCooldownRemaining = 6
        let recruit = try #require(GameContent.heroes.first { !base.roster.isUnlocked($0) })
        #expect(base.roster.progressions[recruit.id] == nil)
        let event = try #require(GameContent.recruitEvents.first { $0.unlockCombatantID == recruit.id })
        let firstStage = try #require(mysteryStages.first)
        let secondStage = try #require(mysteryStages.dropFirst().first)
        var first = base
        var second = base
        try recruitCombatant(event: event, stage: firstStage, save: &first)
        try recruitCombatant(event: event, stage: secondStage, save: &second)
        #expect(first.roster.progressions[recruit.id] == .initial)
        #expect(second.roster.progressions[recruit.id] == .initial)
        #expect(first.roster.grantExperience(4, to: recruit) == 4)
        #expect(second.roster.grantExperience(7, to: recruit) == 7)
        #expect(!CloudSaveMerge.hasDuplicateClaim(incoming: first, existing: second, base: base))

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: preferIncoming)
        let context = try PersistenceTestContext()
        try SaveTestSupport.writeRoot(snapshotRoundTrip(merged), to: context.storeURL())
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.isUnlocked(recruit))
        #expect(reloaded.roster.progressions[recruit.id] == CombatantProgression.initial.addingExperience(11))
        #expect(reloaded.corruptionAltarCooldownRemaining == 4)
    }

    @Test(arguments: [true, false])
    func `new recruit XP stays conservative for unrelated saves and duplicate claims`(sharedBase: Bool) throws {
        let base = PlayerSave.fresh
        let recruit = try #require(GameContent.heroes.first { !base.roster.isUnlocked($0) })
        let event = try #require(GameContent.recruitEvents.first { $0.unlockCombatantID == recruit.id })
        let stage = try #require(mysteryStages.first)
        var first = base
        var second = base
        try recruitCombatant(event: event, stage: stage, save: &first)
        try recruitCombatant(event: event, stage: stage, save: &second)
        #expect(first.roster.grantExperience(4, to: recruit) == 4)
        #expect(second.roster.grantExperience(7, to: recruit) == 7)

        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: sharedBase ? base : nil, preferIncoming: true)
        #expect(merged.roster.progressions[recruit.id] == CombatantProgression.initial.addingExperience(7))
    }

    private var mysteryStages: [Stage] {
        GameContent.chapters.flatMap(\.stages).filter {
            if case .mysteryEvent = $0.encounter {
                true
            } else {
                false
            }
        }
    }

    private func claimMystery(stage: Stage, save: inout PlayerSave) throws {
        let event = try #require(GameContent.mysteryEvent(matching: "mana-berries"))
        var random = SeededRandomNumberGenerator(seed: 1)
        let encounter = EncounterIdentity(location: .journey(stageID: stage.id), save: save)
        let offers = try MysteryOfferPersistence.prepare(
            event: event, encounter: encounter, save: &save, using: &random,
        )
        let offer = try #require(offers.first)
        let request = MysteryEncounterRequest(encounter: encounter, event: event, displayedOffers: offers)
        let outcome = try MysteryEncounterResolution.resolve(choiceID: offer.choiceID, request: request, save: &save, using: &random).get()
        guard case .reward = outcome else {
            Issue.record("The pinned Mystery offer must be claimable")
            return
        }
    }

    private func recruitCombatant(event: MysteryEvent, stage: Stage, save: inout PlayerSave) throws {
        let request = MysteryEncounterRequest(
            encounter: EncounterIdentity(location: .journey(stageID: stage.id), save: save),
            event: event, displayedOffers: [],
        )
        var random = SeededRandomNumberGenerator(seed: 1)
        let outcome = try MysteryEncounterResolution.resolve(choiceID: nil, request: request, save: &save, using: &random).get()
        let combatantID = try #require(event.unlockCombatantID)
        #expect(outcome == .reveal(unlockedCombatantID: combatantID))
    }

    private func snapshotRoundTrip(_ save: PlayerSave) throws -> PlayerSave {
        let data = try JSONEncoder().encode(CloudSaveSnapshot(save))
        return try JSONDecoder().decode(CloudSaveSnapshot.self, from: data).restored()
    }
}
