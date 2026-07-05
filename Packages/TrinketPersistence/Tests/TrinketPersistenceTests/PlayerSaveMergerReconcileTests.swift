import XCTest
@testable import TrinketPersistence

final class PlayerSaveMergerReconcileTests: XCTestCase {
    private let earlier = Date(timeIntervalSince1970: 1600000000)
    private let later = Date(timeIntervalSince1970: 1800000000)
    private let syncedAt = Date(timeIntervalSince1970: 1700000000)

    func testHigherSessionGenerationWinsOverNewerTimestamp() {
        var local = SaveTestSupport.makeSave(modifiedAt: later, gold: 50)
        local.sessionGeneration = 1
        var remoteSave = SaveTestSupport.makeSave(modifiedAt: earlier, gold: 99)
        remoteSave.sessionGeneration = 2
        let remote = RemotePlayerSave(save: remoteSave, modifiedAt: earlier, recordChangeTag: "remote")

        let outcome = PlayerSaveMerger.reconcile(local: local, remote: remote)

        XCTAssertEqual(outcome, .applyRemote(remoteSave))
    }

    func testLowerSessionGenerationUploadsLocalDespiteOlderTimestamp() {
        var local = SaveTestSupport.makeSave(modifiedAt: later, gold: 42)
        local.sessionGeneration = 3
        var remoteSave = SaveTestSupport.makeSave(modifiedAt: earlier, gold: 5)
        remoteSave.sessionGeneration = 2
        let remote = RemotePlayerSave(save: remoteSave, modifiedAt: earlier, recordChangeTag: "remote")

        let outcome = PlayerSaveMerger.reconcile(local: local, remote: remote)

        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testEqualGenerationAndTimestampMergesProgress() {
        var local = SaveTestSupport.makeSave(modifiedAt: syncedAt, gold: 10)
        local.journey.completedStageIDs.insert("chapter-1-stage-1")
        var remoteSave = SaveTestSupport.makeSave(modifiedAt: syncedAt, gold: 20)
        remoteSave.journey.claimedRewardStageIDs.insert("chapter-1-stage-1")
        let remote = RemotePlayerSave(save: remoteSave, modifiedAt: syncedAt, recordChangeTag: "remote")

        let outcome = PlayerSaveMerger.reconcile(local: local, remote: remote)

        guard case let .applyMerged(merged) = outcome else {
            return XCTFail("Expected merged outcome, got \(outcome)")
        }
        XCTAssertEqual(merged.roster.gold, 32)
        XCTAssertTrue(merged.journey.completedStageIDs.contains("chapter-1-stage-1"))
        XCTAssertTrue(merged.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    func testEqualGenerationMergesDespiteDifferentTimestamps() {
        var local = SaveTestSupport.makeSave(modifiedAt: later, gold: 10)
        local.journey.completedStageIDs.insert("chapter-1-stage-1")
        var remoteSave = SaveTestSupport.makeSave(modifiedAt: earlier, gold: 20)
        remoteSave.journey.claimedRewardStageIDs.insert("chapter-1-stage-1")
        let remote = RemotePlayerSave(save: remoteSave, modifiedAt: earlier, recordChangeTag: "remote")

        let outcome = PlayerSaveMerger.reconcile(local: local, remote: remote)

        guard case let .applyMerged(merged) = outcome else {
            return XCTFail("Expected merged outcome, got \(outcome)")
        }
        XCTAssertEqual(merged.roster.gold, 32)
        XCTAssertTrue(merged.journey.completedStageIDs.contains("chapter-1-stage-1"))
        XCTAssertTrue(merged.journey.claimedRewardStageIDs.contains("chapter-1-stage-1"))
    }

    func testPickAuthoritativeUsesSessionGeneration() {
        var local = SaveTestSupport.makeSave(modifiedAt: later, gold: 1)
        local.sessionGeneration = 1
        var remote = SaveTestSupport.makeSave(modifiedAt: earlier, gold: 99)
        remote.sessionGeneration = 2

        let picked = PlayerSaveMerger.pickAuthoritative(local: local, remote: remote)

        XCTAssertEqual(picked.roster.gold, 99)
        XCTAssertEqual(picked.sessionGeneration, 2)
    }

    func testRemoteMissingUploadsLocal() {
        let local = SaveTestSupport.makeSave(modifiedAt: syncedAt)
        let outcome = PlayerSaveMerger.reconcile(local: local, remote: nil)
        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testLocalMissingAppliesRemote() {
        let remote = SaveTestSupport.makeRemote(modifiedAt: syncedAt)
        let outcome = PlayerSaveMerger.reconcile(local: nil, remote: remote)
        XCTAssertEqual(outcome, .applyRemote(remote.save))
    }

    func testBothMissingKeepsLocal() {
        let outcome = PlayerSaveMerger.reconcile(local: nil, remote: nil)
        XCTAssertEqual(outcome, .keepLocal)
    }

    func testEqualSavesKeepLocal() {
        let syncedAt = Date(timeIntervalSince1970: 1700000000)
        let local = SaveTestSupport.makeSave(modifiedAt: syncedAt, gold: 25)
        let remote = RemotePlayerSave(
            save: local,
            modifiedAt: syncedAt,
            recordChangeTag: "remote"
        )

        let outcome = PlayerSaveMerger.reconcile(local: local, remote: remote)

        XCTAssertEqual(outcome, .keepLocal)
    }

    func testMergedEqualToBothKeepsLocal() {
        let syncedAt = Date(timeIntervalSince1970: 1700000000)
        let local = SaveTestSupport.makeSave(modifiedAt: syncedAt, gold: 25)
        var remoteSave = SaveTestSupport.makeSave(modifiedAt: syncedAt, gold: 25)
        remoteSave.journey.completedStageIDs = local.journey.completedStageIDs
        remoteSave.journey.claimedRewardStageIDs = local.journey.claimedRewardStageIDs
        let remote = RemotePlayerSave(
            save: remoteSave,
            modifiedAt: syncedAt,
            recordChangeTag: "remote"
        )

        let outcome = PlayerSaveMerger.reconcile(local: local, remote: remote)

        XCTAssertEqual(outcome, .keepLocal)
    }
}
