import XCTest
@testable import TrinketPersistence

final class PlayerSaveReconcilerTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1700000000)
    private let earlier = Date(timeIntervalSince1970: 1600000000)
    private let later = Date(timeIntervalSince1970: 1800000000)

    func testRemoteMissingUploadsLocal() {
        let local = SaveTestSupport.makeSave(modifiedAt: now)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: nil)
        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testLocalMissingAppliesRemote() {
        let remote = SaveTestSupport.makeRemote(modifiedAt: now)
        let outcome = PlayerSaveReconciler.reconcile(local: nil, remote: remote)
        XCTAssertEqual(outcome, .applyRemote(remote.save))
    }

    func testNewerRemoteWins() {
        let local = SaveTestSupport.makeSave(modifiedAt: earlier)
        let remote = SaveTestSupport.makeRemote(modifiedAt: later)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)
        XCTAssertEqual(outcome, .applyRemote(remote.save))
    }

    func testNewerLocalWins() {
        let local = SaveTestSupport.makeSave(modifiedAt: later)
        let remote = SaveTestSupport.makeRemote(modifiedAt: earlier)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)
        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testEqualModifiedAtUploadsLocal() {
        let local = SaveTestSupport.makeSave(modifiedAt: now)
        let remote = SaveTestSupport.makeRemote(modifiedAt: now)
        let outcome = PlayerSaveReconciler.reconcile(local: local, remote: remote)
        XCTAssertEqual(outcome, .uploadLocal)
    }

    func testBothMissingKeepsLocal() {
        let outcome = PlayerSaveReconciler.reconcile(local: nil, remote: nil)
        XCTAssertEqual(outcome, .keepLocal)
    }
}
