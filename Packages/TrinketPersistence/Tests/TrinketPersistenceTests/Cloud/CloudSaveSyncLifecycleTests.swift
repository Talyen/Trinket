import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

extension CloudSaveSyncTests {
    @Test(arguments: [false, true])
    @MainActor func `one device serializes production commands through their own receipts`(cancelUpgrade: Bool) async throws {
        let context = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        let store = try cloudStore(context, transport: transport)
        try seedHomestead(store)
        let sync = try #require(store.cloudSync)
        #expect(await sync.synchronize())
        await transport.advance(PlayerHomesteadState.secondsPerDay)
        let gate = ReconciliationGate()
        await transport.onNextFetch { await gate.pauseOnce() }
        let collection = Task { await sync.perform(.collect) }
        await gate.waitUntilPaused()
        var upgradeStarted = false
        let upgrade = Task {
            upgradeStarted = true
            return await sync.perform(.upgrade(.wheatField, 2))
        }
        while !upgradeStarted {
            await Task.yield()
        }
        if cancelUpgrade {
            upgrade.cancel()
        }
        await gate.resume()
        #expect(await collection.value == .collected([.food: 1, .gold: 1]))
        #expect(await upgrade.value == (cancelUpgrade ? nil : .upgraded))
        let reloaded = try context.makeReloadedStore()
        #expect(reloaded.roster.gold == 101)
        #expect(reloaded.homestead.resources[.food] == 1)
        #expect(reloaded.homestead.tier(for: .wheatField) == (cancelUpgrade ? 1 : 2))
        #expect(reloaded.homestead.resources[.wood] == (cancelUpgrade ? 99 : 91))
        #expect(reloaded.cloudDeviceState.account.pending == nil)
        #expect(await sync.perform(.collect) == .collected([:]))
    }

    @Test(arguments: [false, true])
    @MainActor func `reconciliation suspension preserves newer earnings and rejects cancelled uploads`(cancelUpload: Bool) async throws {
        let context = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        let store = try cloudStore(context, transport: transport)
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.persistFixtureBatch(logging: "Offline earnings") { $0.roster.gold += 17 })
        let journalIDs = store.cloudDeviceState.account.journal?.records.map(\.id)
        let receiptCount = await transport.account().receipts.count
        let gate = ReconciliationGate()
        let sync = PlayerSaveCloudSync(store: store, transport: transport) { request, server in
            let resolution = try await CloudSavePlanner.resolve(request, against: server)
            // Model work that completes even after cancellation. The coordinator
            // must still reject its result before any server write.
            await gate.pauseOnce()
            return resolution
        }
        let upload = Task { await sync.synchronize() }
        await gate.waitUntilPaused()
        if cancelUpload {
            sync.accountDidChange()
        } else {
            #expect(store.persistFixtureBatch(logging: "Earnings during reconciliation") { $0.roster.gold += 5 })
        }
        await gate.resume()
        #expect(await upload.value == !cancelUpload)
        if cancelUpload {
            #expect(await transport.account().receipts.count == receiptCount)
            #expect(await transport.account().head?.head.revision.snapshot.roster.gold == 0)
            #expect(store.cloudDeviceState.account.journal?.records.map(\.id) == journalIDs)
            #expect(try context.makeReloadedStore().roster.gold == 17)
            #expect(await sync.synchronize() == true)
        }
        let expectedGold = cancelUpload ? 17 : 22
        #expect(store.roster.gold == expectedGold)
        #expect(await transport.account().head?.head.revision.snapshot.roster.gold == expectedGold)
        #expect(store.cloudDeviceState.account.journal?.isEmpty == true)
        #expect(try context.makeReloadedStore().roster.gold == expectedGold)
        let finalReceiptCount = await transport.account().receipts.count
        #expect(await sync.synchronize() == true)
        #expect(await transport.account().receipts.count == finalReceiptCount)
    }

    @Test @MainActor func `account change during fetch preserves local outbox without leaking into new account`() async throws {
        let context = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        let store = try cloudStore(context, transport: transport)
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.persistFixtureBatch(logging: "Offline earnings") { $0.roster.gold += 17 })
        let pending = store.cloudDeviceState.account.journal?.records.map(\.id)
        await transport.onNextFetch { await transport.switchAccount("player-b") }
        #expect(await store.cloudSync?.synchronize() == false)
        #expect(store.roster.gold == 17)
        #expect(store.cloudDeviceState.account.journal?.records.map(\.id) == pending)
        #expect(await transport.account("player-b").head == nil)
        await transport.switchAccount("player-a")
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(await transport.account("player-a").head?.head.revision.snapshot.roster.gold == 17)
        let receiptCount = await transport.account("player-a").receipts.count
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(await transport.account("player-a").receipts.count == receiptCount)
        #expect(try context.makeReloadedStore().roster.gold == 17)
    }
}

private actor ReconciliationGate {
    private var didPause = false
    private var paused: CheckedContinuation<Void, Never>?
    private var waiter: CheckedContinuation<Void, Never>?

    func pauseOnce() async {
        guard !didPause else { return }
        didPause = true
        await withCheckedContinuation { continuation in
            paused = continuation
            waiter?.resume()
            waiter = nil
        }
    }

    func waitUntilPaused() async {
        guard !didPause else { return }
        await withCheckedContinuation { waiter = $0 }
    }

    func resume() {
        paused?.resume()
        paused = nil
    }
}
