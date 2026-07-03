import Foundation
@testable import TrinketPersistence

enum MockSyncError: Error {
    case fetchFailed
    case uploadFailed
}

actor MockPlayerSaveSync: PlayerSaveSyncing {
    private var accountStatusResult: PlayerSaveAccountStatus = .available
    private var remoteSave: RemotePlayerSave?
    private var fetchError: Error?
    private var uploadError: Error?
    private var uploadedSaves: [PlayerSave] = []
    private var fetchCount = 0
    private var subscribeInvocations = 0
    private var uploadWaiters: [CheckedContinuation<Void, Never>] = []
    private var storedChangeTag: String?

    func setAccountStatus(_ status: PlayerSaveAccountStatus) {
        accountStatusResult = status
    }

    func setRemoteSave(_ remote: RemotePlayerSave?) {
        remoteSave = remote
        storedChangeTag = remote?.recordChangeTag
    }

    func setFetchError(_ error: Error?) {
        fetchError = error
    }

    func setUploadError(_ error: Error?) {
        uploadError = error
    }

    func uploadedSaveCount() -> Int {
        uploadedSaves.count
    }

    func uploadedSavesSnapshot() -> [PlayerSave] {
        uploadedSaves
    }

    func fetchCallCount() -> Int {
        fetchCount
    }

    func subscribeInvocationCount() -> Int {
        subscribeInvocations
    }

    func waitUntilUploadCount(atLeast expected: Int) async {
        if uploadedSaves.count >= expected {
            return
        }
        while uploadedSaves.count < expected {
            await withCheckedContinuation { continuation in
                uploadWaiters.append(continuation)
            }
        }
    }

    func accountStatus() async -> PlayerSaveAccountStatus {
        await Task.yield()
        return accountStatusResult
    }

    func fetchRemoteSave() async throws -> RemotePlayerSave? {
        await Task.yield()
        fetchCount += 1
        if let fetchError {
            throw fetchError
        }
        return remoteSave
    }

    func upload(_ save: PlayerSave, replacingRecordChangeTag expectedTag: String?) async throws -> String? {
        await Task.yield()
        if let uploadError {
            throw uploadError
        }
        if let expectedTag,
           let storedChangeTag,
           expectedTag != storedChangeTag,
           let remoteSave
        {
            throw PlayerSaveSyncError.recordConflict(remoteSave)
        }
        uploadedSaves.append(save)
        storedChangeTag = "tag-\(uploadedSaves.count)"
        resumeUploadWaiters()
        return storedChangeTag
    }

    func subscribeToChanges() async throws {
        await Task.yield()
        subscribeInvocations += 1
    }

    private func resumeUploadWaiters() {
        let waiters = uploadWaiters
        uploadWaiters = []
        for waiter in waiters {
            waiter.resume()
        }
    }
}
