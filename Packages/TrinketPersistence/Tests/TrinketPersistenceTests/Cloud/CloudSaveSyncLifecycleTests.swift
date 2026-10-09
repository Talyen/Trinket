import Testing
@testable import TrinketPersistence

extension CloudSaveSyncTests {
    @Test @MainActor func `account change during fetch preserves local outbox without leaking into new account`() async throws {
        let context = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        let store = try cloudStore(context, transport: transport)
        #expect(await store.cloudSync?.synchronize() == true)
        #expect(store.persistBatch(logging: "Offline earnings") { $0.roster.gold += 17 })
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
