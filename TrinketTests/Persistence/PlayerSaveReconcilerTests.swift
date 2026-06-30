import XCTest
@testable import Trinket

final class PlayerSaveReconcilerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)
    private let earlier = Date(timeIntervalSince1970: 1_600_000_000)
    private let later = Date(timeIntervalSince1970: 1_800_000_000)

    func testRemoteMissingUploadsLocal() {
        let local = makeSave(modifiedAt: now)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: nil)
        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testLocalMissingAppliesRemote() {
        let remote = makeRemote(modifiedAt: now)
        let outcome = PlayerSaveReconciler.reconcile(local: nil, remote: remote)
        XCTAssertEqual(outcome, .applyRemote(remote.save))
    }

    func testNewerRemoteWins() {
        let local = makeSave(modifiedAt: earlier)
        let remote = makeRemote(modifiedAt: later)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)
        XCTAssertEqual(outcome, .applyRemote(remote.save))
    }

    func testNewerLocalWins() {
        let local = makeSave(modifiedAt: later)
        let remote = makeRemote(modifiedAt: earlier)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)
        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testEqualModifiedAtKeepsLocal() {
        let local = makeSave(modifiedAt: now)
        let remote = makeRemote(modifiedAt: now)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)
        XCTAssertEqual(outcome, .keepLocal)
    }

    func testBothMissingKeepsLocal() {
        let outcome = PlayerSaveReconciler.reconcile(local: nil, remote: nil)
        XCTAssertEqual(outcome, .keepLocal)
    }

    private func makeSave(modifiedAt: Date) -> PlayerSave {
        PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: modifiedAt,
            journey: .initial,
            roster: SavedRosterState(.freshStart),
            inventory: SavedInventoryState(.freshStart)
        )
    }

    private func makeRemote(modifiedAt: Date) -> RemotePlayerSave {
        RemotePlayerSave(
            save: makeSave(modifiedAt: modifiedAt),
            modifiedAt: modifiedAt,
            recordChangeTag: "tag"
        )
    }
}
