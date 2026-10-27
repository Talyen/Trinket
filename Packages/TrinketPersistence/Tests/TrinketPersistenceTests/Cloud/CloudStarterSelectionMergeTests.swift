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

    @Test func `first attachment after a reset merges local starter progress`() throws {
        var cloud = establishedSave()
        cloud.roster = PlayerRosterState(
            activeHeroID: "knight", activeCompanionID: "bear",
            unlockedHeroIDs: ["knight"], unlockedCompanionIDs: ["bear"],
            abilityLoadouts: [:], progressions: [:], equipmentLoadouts: [:], gold: 68,
        )
        var local = unfinishedSave()
        local.starterSelection = .complete
        local.roster.gold = 5
        local.homestead.pendingProduction[.food] = 4
        let server = CloudServerSave(
            head: CloudSaveHead(
                epoch: "reset-epoch", resetCount: 1, authoritySequence: 0,
                revision: CloudSaveRevision(id: "cloud", clock: ["first-device": 1], snapshot: CloudSaveSnapshot(cloud)),
            ),
            changeToken: Data(), serverTime: cloud.homestead.lastProductionAt,
        )
        let request = CloudSaveRequest(
            id: "first-upload", action: .upload, baseEpoch: nil, baseRevisionID: nil, authoritySequence: 0,
            revision: CloudSaveRevision(id: "first-upload", clock: ["new-device": 1], snapshot: CloudSaveSnapshot(local)),
        )

        let resolution = try CloudSaveReconciler.resolve(request, against: server)
        let merged = try resolution.head.revision.snapshot.restored()
        #expect(merged.roster.unlockedHeroIDs.isSuperset(of: ["knight", "ranger"]))
        #expect(merged.roster.unlockedCompanionIDs.isSuperset(of: ["bear", "wolf"]))
        #expect(merged.roster.gold == 68)
        #expect(merged.homestead.pendingProduction[.food] == 4)
        #expect(resolution.head.epoch == "reset-epoch")
        #expect(resolution.backups.count == 2)

        let retry = CloudSaveRequest(
            id: "second-upload", action: .upload, baseEpoch: nil, baseRevisionID: nil, authoritySequence: 0,
            revision: CloudSaveRevision(id: "second-upload", clock: ["new-device": 2], snapshot: CloudSaveSnapshot(local)),
        )
        let retryServer = CloudServerSave(head: resolution.head, changeToken: Data(), serverTime: server.serverTime)
        let retried = try CloudSaveReconciler.resolve(retry, against: retryServer).head.revision.snapshot.restored()
        #expect(retried.roster.gold == merged.roster.gold)
        #expect(retried.homestead.pendingProduction[.food] == merged.homestead.pendingProduction[.food])
        #expect(retried.roster.unlockedHeroIDs == merged.roster.unlockedHeroIDs)
    }

    @Test func `a stale reset request cannot reset a newer epoch`() throws {
        let cloud = establishedSave()
        let server = CloudServerSave(
            head: CloudSaveHead(
                epoch: "new-epoch", resetCount: 2, authoritySequence: 0,
                revision: CloudSaveRevision(id: "cloud", clock: ["first-device": 1], snapshot: CloudSaveSnapshot(cloud)),
            ),
            changeToken: Data(), serverTime: cloud.homestead.lastProductionAt,
        )
        let request = CloudSaveRequest(
            id: "stale-reset", action: .reset, baseEpoch: "old-epoch", baseRevisionID: "old", authoritySequence: 0,
            revision: CloudSaveRevision(id: "stale-reset", clock: ["second-device": 1], snapshot: CloudSaveSnapshot(.fresh)),
        )

        let existingRoster = try server.head.revision.snapshot.restored().roster
        let resolution = try CloudSaveReconciler.resolve(request, against: server)
        #expect(resolution.receipt.outcome == .progressChanged)
        #expect(resolution.head.epoch == "new-epoch")
        #expect(resolution.head.resetCount == 2)
        #expect(try resolution.head.revision.snapshot.restored().roster == existingRoster)
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
