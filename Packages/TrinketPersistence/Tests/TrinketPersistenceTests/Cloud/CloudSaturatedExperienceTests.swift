import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudSaturatedExperienceTests {
    @Test(arguments: [false, true]) @MainActor
    func `XP beyond the lifetime total limit survives action replay and reload`(crossesLevel: Bool) throws {
        var before = PlayerSave.testSeed
        let heroID = before.roster.activeHeroID
        let base = CombatantProgression.at(level: 4000000)
        before.roster.progressions[heroID] = CombatantProgression(
            level: base.level, currentXP: crossesLevel ? base.requiredXP - 2 : 0,
            requiredXP: base.requiredXP,
        )
        var after = before
        after.roster.progressions[heroID] = before.roster.progressions[heroID]?.addingExperience(5)
        let action = ResolvedSaveAction(
            before: CloudSaveSnapshot(before), after: CloudSaveSnapshot(after), kind: .reward, claim: nil,
        )
        #expect(action.receipt.effects.experience[heroID] == 5)
        let recordedLegacy = CloudEconomicAction.record(from: before, to: after)
        let legacy = try #require(recordedLegacy)
        #expect(legacy.experience[heroID] == 5)
        #expect(throws: SaveEconomicMutation.ValidationFailure.self) {
            try SaveEconomicMutation.validate(from: before, to: after, receipts: [])
        }
        try SaveEconomicMutation.validate(from: before, to: after, receipts: [action.receipt])

        let head = CloudSaveHead(
            epoch: "epoch", resetCount: 0, authoritySequence: 0,
            revision: CloudSaveRevision(id: "before", clock: [:], snapshot: CloudSaveSnapshot(before)),
        )
        var replay = CloudReceiptReplay(head: head)
        let replayed = try replay.apply(action, collectionPositions: [:], onto: before)
        #expect(replayed.roster.progressions[heroID] == after.roster.progressions[heroID])
        let context = try PersistenceTestContext()
        let restored = try context.seedAndReload(replayed).currentSave
        #expect(restored.roster.progressions[heroID] == after.roster.progressions[heroID])
    }

    @Test func `independent XP at saturated lifetime totals combines before rollover`() {
        var base = PlayerSave.testSeed
        let heroID = base.roster.activeHeroID
        base.roster.progressions[heroID] = .at(level: 4000000)
        var first = base
        var second = base
        first.roster.progressions[heroID] = base.roster.progressions[heroID]?.addingExperience(5)
        second.roster.progressions[heroID] = base.roster.progressions[heroID]?.addingExperience(7)
        let merged = CloudSaveMerge.merge(incoming: first, existing: second, base: base, preferIncoming: true)
        #expect(merged.roster.progressions[heroID] == base.roster.progressions[heroID]?.addingExperience(12))
    }
}
