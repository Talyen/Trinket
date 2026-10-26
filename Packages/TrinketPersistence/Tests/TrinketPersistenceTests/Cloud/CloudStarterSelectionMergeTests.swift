import Foundation
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketPersistence

struct CloudStarterSelectionMergeTests {
    @Test(arguments: [false, true]) @MainActor
    func `newer unfinished onboarding cannot reopen completed selection through merge and reload`(incompleteIncoming: Bool) throws {
        let established = establishedSave()
        let unfinished = unfinishedSave()
        let merged = CloudSaveMerge.merge(
            incoming: incompleteIncoming ? unfinished : established,
            existing: incompleteIncoming ? established : unfinished,
            base: nil, preferIncoming: incompleteIncoming,
        )
        let context = try PersistenceTestContext()
        let store = try context.seedAndReload(merged)

        #expect(store.starterSelection == .complete)
        #expect(store.roster.unlockedHeroIDs == established.roster.unlockedHeroIDs)
        #expect(store.roster.unlockedCompanionIDs == established.roster.unlockedCompanionIDs)
        #expect(store.roster.progressions == established.roster.progressions)
        let before = store.currentSave
        #expect(store.completeStarterSelection(companionID: "wolf") == SaveActionAttempt(false))
        #expect(store.currentSave == before)
        #expect(try context.makeReloadedStore().roster == before.roster)
    }

    @Test func `first attachment after choosing a Hero imports completed onboarding`() throws {
        let established = establishedSave()
        let unfinished = unfinishedSave()
        let server = CloudServerSave(
            head: CloudSaveHead(
                epoch: "epoch", resetCount: 0, authoritySequence: 0,
                revision: CloudSaveRevision(id: "established", clock: ["first-device": 1], snapshot: CloudSaveSnapshot(established)),
            ),
            changeToken: Data(), serverTime: established.homestead.lastProductionAt,
        )
        let request = CloudSaveRequest(
            id: "first-upload", action: .upload, baseEpoch: nil, baseRevisionID: nil, authoritySequence: 0,
            revision: CloudSaveRevision(id: "first-upload", clock: ["new-device": 1], snapshot: CloudSaveSnapshot(unfinished)),
        )

        let imported = try CloudSaveReconciler.resolve(request, against: server).head.revision.snapshot.restored()

        #expect(imported.starterSelection == .complete)
        #expect(imported.roster.unlockedHeroIDs == established.roster.unlockedHeroIDs)
        #expect(imported.roster.progressions == established.roster.progressions)
    }

    @Test(arguments: [false, true])
    func `Hero selection survives a newer unstarted branch and same-phase choices use recency`(incompleteIncoming: Bool) {
        let chosen = unfinishedSave()
        var unstarted = chosen
        unstarted.starterSelection = .fresh
        unstarted.modifiedAt = chosen.modifiedAt.addingTimeInterval(1)
        let merged = CloudSaveMerge.merge(
            incoming: incompleteIncoming ? unstarted : chosen,
            existing: incompleteIncoming ? chosen : unstarted,
            base: nil, preferIncoming: incompleteIncoming,
        )
        #expect(merged.starterSelection == chosen.starterSelection)

        var laterChoice = chosen
        laterChoice.starterSelection = StarterSelectionState(phase: .chooseCompanion, heroID: "wizard")
        laterChoice.modifiedAt = chosen.modifiedAt.addingTimeInterval(1)
        let latest = CloudSaveMerge.merge(
            incoming: incompleteIncoming ? laterChoice : chosen,
            existing: incompleteIncoming ? chosen : laterChoice,
            base: nil, preferIncoming: incompleteIncoming,
        )
        #expect(latest.starterSelection == laterChoice.starterSelection)
    }

    @Test func `action residual and receipt merges cannot regress completed onboarding`() throws {
        let established = establishedSave()
        var before = unfinishedSave()
        before.starterSelection = .fresh
        let after = unfinishedSave()
        let replayed = try CloudSaveMerge.mergeChanges(
            from: CloudSaveSnapshot(before), to: CloudSaveSnapshot(after), into: established,
        )
        #expect(replayed.starterSelection == .complete)
        #expect(replayed.roster.progressions == established.roster.progressions)
        let legacyReceiptMerge = CloudSaveMerge.merge(
            incoming: after, existing: established, base: before, preferIncoming: true, economy: .receipts,
        )
        #expect(legacyReceiptMerge.starterSelection == .complete)
    }

    private func establishedSave() -> PlayerSave {
        var save = SaveTestSupport.makeSave(modifiedAt: Date(timeIntervalSince1970: 100), worldSeed: PlayerSave.testWorldSeed)
        save.starterSelection = .complete
        return save
    }

    private func unfinishedSave() -> PlayerSave {
        var save = SaveTestSupport.makeSave(
            modifiedAt: Date(timeIntervalSince1970: 200),
            worldSeed: PlayerSave.testWorldSeed + 1, roster: .freshStart,
        )
        save.starterSelection = StarterSelectionState(phase: .chooseCompanion, heroID: "ranger")
        return save
    }
}
