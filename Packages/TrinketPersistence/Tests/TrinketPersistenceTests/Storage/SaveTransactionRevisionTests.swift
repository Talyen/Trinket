import Testing
@testable import TrinketPersistence

@MainActor
struct SaveTransactionRevisionTests {
    @Test(arguments: [false, true])
    func `outer candidate cannot overwrite a nested durable command`(recordsReceipts: Bool) throws {
        let context = try PersistenceTestContext()
        let store = try context.makeSaveStore()
        let mutate: (inout PlayerSave) -> Result<Void, Never> = { save in
            save.corruptionAltarCooldownRemaining = 1
            #expect(store.persistBatch(logging: "Nested command") { $0.corruptionAltarCooldownRemaining = 3 })
            return .success(())
        }
        let result: SaveTransactionResult<Void, Never> = if recordsReceipts {
            store.persistTransaction(logging: "Outer command") { save, _ in mutate(&save) }
        } else {
            store.persistTransaction(logging: "Outer command", mutate)
        }
        guard case .persistFailed(.invalidSave) = result else {
            Issue.record("Expected rejection of an obsolete save candidate")
            return
        }
        #expect(store.corruptionAltarCooldownRemaining == 3)
        #expect(try context.makeReloadedStore().corruptionAltarCooldownRemaining == 3)
    }
}
