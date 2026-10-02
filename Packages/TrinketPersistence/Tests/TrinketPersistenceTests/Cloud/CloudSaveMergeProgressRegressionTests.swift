import Foundation
import Testing
import TrinketContent
import TrinketCore
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudSaveMergeProgressRegressionTests {
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
