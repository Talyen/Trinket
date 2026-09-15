import Foundation
@testable import TrinketPersistence

actor CloudSaveTestTransport: CloudSaveTransport {
    struct Account {
        var head: CloudServerSave?
        var receipts: [String: CloudSaveReceipt] = [:]
        var backups: [CloudSaveBackup] = []
    }

    var accounts: [String: Account] = [:]
    var currentAccount: String? = "player-a"
    var now = Date(timeIntervalSince1970: 2000000000)
    var token = 0
    var offline = false
    var failNextCommit = false
    var loseNextCommitResponse = false
    var conflictsRemaining = 0
    /// Runs on the MainActor because test actions mutate the @MainActor
    /// store between fetch and verify. Awaiting it from this actor serializes
    /// the fake the same way the real transport serializes on the store.
    var nextFetchAction: (@MainActor @Sendable () -> Void)?

    func configure(
        offline: Bool = false,
        failCommit: Bool = false,
        loseResponse: Bool = false,
        conflicts: Int = 0,
    ) {
        self.offline = offline
        failNextCommit = failCommit
        loseNextCommitResponse = loseResponse
        conflictsRemaining = conflicts
    }

    func switchAccount(_ id: String?) {
        currentAccount = id
    }

    func advance(_ seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }

    func onNextFetch(_ action: @escaping @MainActor @Sendable () -> Void) {
        nextFetchAction = action
    }

    func account(_ id: String = "player-a") -> Account {
        accounts[id] ?? Account()
    }

    func accountID() throws -> String? {
        if offline {
            throw CloudSaveError.unavailable
        }
        return currentAccount
    }

    func fetchHead(accountID: String) async throws -> CloudServerSave? {
        try verify(accountID)
        if let action = nextFetchAction {
            nextFetchAction = nil
            await action()
        }
        try verify(accountID)
        return accounts[accountID]?.head
    }

    func refreshTime(accountID: String, head: CloudServerSave) throws -> CloudServerSave {
        try verify(accountID)
        guard accounts[accountID]?.head?.changeToken == head.changeToken else { throw CloudSaveError.conflict }
        let touched = server(head.head)
        accounts[accountID]?.head = touched
        return touched
    }

    func fetchReceipt(accountID: String, requestID: String) throws -> CloudSaveReceipt? {
        try verify(accountID)
        return accounts[accountID]?.receipts[requestID]
    }

    func commit(
        accountID: String,
        replacing: CloudServerSave?,
        head: CloudSaveHead,
        receipt: CloudSaveReceipt,
        backups: [CloudSaveBackup],
    ) throws -> CloudServerSave {
        try verify(accountID)
        if conflictsRemaining > 0 {
            conflictsRemaining -= 1
            throw CloudSaveError.conflict
        }
        if failNextCommit {
            failNextCommit = false
            throw CloudSaveError.unavailable
        }
        var account = accounts[accountID] ?? Account()
        guard account.head?.changeToken == replacing?.changeToken,
              account.receipts[receipt.requestID] == nil else { throw CloudSaveError.conflict }
        let saved = server(head)
        account.head = saved
        account.receipts[receipt.requestID] = receipt
        account.backups += backups
        accounts[accountID] = account
        if loseNextCommitResponse {
            loseNextCommitResponse = false
            throw CloudSaveError.unavailable
        }
        return saved
    }

    private func server(_ head: CloudSaveHead) -> CloudServerSave {
        token += 1
        return CloudServerSave(head: head, changeToken: Data(String(token).utf8), serverTime: now)
    }

    private func verify(_ accountID: String) throws {
        if offline {
            throw CloudSaveError.unavailable
        }
        guard currentAccount == accountID else { throw CloudSaveError.accountChanged }
    }
}
