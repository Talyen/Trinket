import Foundation
import StoreKit
import Testing
@testable import TrinketAppState

@Suite("Full Game StoreKit", .timeLimit(.minutes(1)))
struct FullGameStoreTests {
    @Test @MainActor
    func `unverified current ownership revokes previously published gameplay access`() async throws {
        let backend = ControlledFullGameStorefront()
        backend.ownership = .purchased
        let store = FullGameStore(storefront: backend.storefront)
        let context = try AppTestContext()
        let state = try context.makeAppState(contentAccess: .free, fullGame: store)

        await store.refreshOwnership()
        state.synchronizePurchaseAccess()
        #expect(state.playerSave.contentAccess.hasFullGame)
        #expect(state.playerSave.contentAccess.allowsChapter(4))

        backend.ownership = .unverified
        await store.refreshOwnership()
        state.synchronizePurchaseAccess()

        #expect(!state.playerSave.contentAccess.hasFullGame)
        #expect(!state.playerSave.contentAccess.allowsChapter(4))
        #expect(!state.preparedContentAccess.hasFullGame)
    }

    @Test @MainActor
    func `an older entitlement refresh cannot revoke a newer restored purchase`() async throws {
        let backend = ControlledFullGameStorefront()
        let response = AsyncStream<FullGameStore.Ownership>.makeStream()
        backend.nextRead = response.stream
        let store = FullGameStore(storefront: backend.storefront)
        let first = Task { await store.refreshOwnership() }
        defer {
            first.cancel()
            response.continuation.finish()
        }
        try await backend.waitForRead(count: 1)
        try #require(backend.readCount == 1, "Entitlement refresh did not start")

        backend.ownership = .purchased
        await store.restore()
        #expect(store.ownership.access.hasFullGame)
        response.continuation.yield(.free)
        response.continuation.finish()
        await first.value

        #expect(store.ownership == .purchased)
        #expect(store.ownership.access.hasFullGame)
    }

    @Test @MainActor
    func `startup retries ownership and unfinished delivery after cancellation`() async throws {
        let backend = ControlledFullGameStorefront()
        let response = AsyncStream<FullGameStore.Ownership>.makeStream()
        backend.nextRead = response.stream
        let store = FullGameStore(storefront: backend.storefront)
        let startup = Task { await store.start() }
        defer {
            startup.cancel()
            response.continuation.finish()
        }
        try await backend.waitForRead(count: 1)
        startup.cancel()
        await startup.value
        #expect(store.ownership == .checking)

        backend.ownership = .purchased
        backend.unfinished = [FullGameTransaction(finish: { @MainActor in
            backend.ownershipAtFinish.append(store.ownership)
        })]
        await store.start()

        #expect(store.ownership == .purchased)
        #expect(backend.ownershipAtFinish == [.purchased])
    }

    @Test @MainActor
    func `unfinished purchase delivery cannot regrant revoked access`() async {
        let backend = ControlledFullGameStorefront()
        let store = FullGameStore(storefront: backend.storefront)
        backend.unfinished = [FullGameTransaction(finish: { @MainActor in
            backend.ownershipAtFinish.append(store.ownership)
        })]

        await store.start()

        #expect(store.ownership == .free)
        #expect(backend.ownershipAtFinish == [.free])
    }

    @Test @MainActor
    func `live delivery reconciles revocation and family access before acknowledgement`() async throws {
        let backend = ControlledFullGameStorefront()
        backend.ownership = .purchased
        let store = FullGameStore(storefront: backend.storefront)
        await store.start()
        #expect(store.ownership == .purchased)
        let receive = try await backend.waitForUpdateReceiver()
        let transaction = FullGameTransaction(finish: { @MainActor in
            backend.ownershipAtFinish.append(store.ownership)
        })

        backend.ownership = .free
        await receive(transaction)
        #expect(!store.ownership.access.hasFullGame)
        backend.ownership = .familyShared
        await receive(transaction)
        #expect(store.ownership.access.hasFullGame)
        #expect(backend.ownershipAtFinish == [.free, .familyShared])

        // Unverified notifications must also invalidate previously granted access
        // when the current entitlement set no longer contains a verified purchase.
        backend.ownership = .unverified
        await receive(FullGameTransaction(finish: nil))
        #expect(store.ownership == .unverified)
        #expect(!store.ownership.access.hasFullGame)
        #expect(backend.ownershipAtFinish.count == 2)
    }

    @Test @MainActor
    func `a superseded delivery cannot grant access or acknowledge discarded ownership`() async throws {
        let backend = ControlledFullGameStorefront()
        backend.ownership = .purchased
        let store = FullGameStore(storefront: backend.storefront)
        await store.start()
        let receive = try await backend.waitForUpdateReceiver()
        let response = AsyncStream<FullGameStore.Ownership>.makeStream()
        backend.nextRead = response.stream
        let transaction = FullGameTransaction(finish: { @MainActor in
            backend.ownershipAtFinish.append(store.ownership)
        })
        let pending = Task { await receive(transaction) }
        defer {
            pending.cancel()
            response.continuation.finish()
        }
        try await backend.waitForRead(count: 2)
        try #require(backend.readCount == 2, "Delivery refresh did not start")

        backend.ownership = .free
        await store.refreshOwnership()
        response.continuation.yield(.purchased)
        response.continuation.finish()
        await pending.value
        #expect(store.ownership == .free)
        #expect(backend.ownershipAtFinish.isEmpty)

        await receive(transaction)
        #expect(backend.ownershipAtFinish == [.free])
    }

    @Test @MainActor
    func `restore failure publishes its outcome and keeps free access`() async {
        let backend = ControlledFullGameStorefront()
        backend.syncError = StoreKitError.networkError(URLError(.notConnectedToInternet))
        let store = FullGameStore(storefront: backend.storefront)

        await store.restore()

        #expect(store.outcome == .restoreFailed)
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isRestoring)
    }

    @Test @MainActor
    func `cancelling and pending never grant access`() async {
        let backend = ControlledFullGameStorefront()
        let store = FullGameStore(storefront: backend.storefront)
        #expect(store.purchaseStarted())
        #expect(!store.purchaseStarted())
        await store.purchaseCompleted(.success(.userCancelled))
        #expect(store.outcome == nil)
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isPurchasing)
        store.purchaseStarted()
        await store.purchaseCompleted(.success(.pending))
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isPurchasing)
        store.purchaseStarted()
        #expect(store.outcome == nil)
        await store.purchaseCompleted(.failure(StoreKitError.networkError(URLError(.notConnectedToInternet))))
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isPurchasing)
        #expect(store.outcome == .purchaseFailed)
        #expect(store.purchaseStarted())
        #expect(store.outcome == nil)
        await store.purchaseCompleted(.failure(StoreKitError.userCancelled))
        #expect(store.outcome == nil)
        #expect(!store.isPurchasing)
        #expect(backend.readCount == 0)
    }
}

@MainActor
private final class ControlledFullGameStorefront {
    var ownership = FullGameStore.Ownership.free
    var nextRead: AsyncStream<FullGameStore.Ownership>?
    var readCount = 0
    var unfinished: [FullGameTransaction] = []
    var receiveUpdate: FullGameStorefront.Receive?
    var ownershipAtFinish: [FullGameStore.Ownership] = []
    var syncError: (any Error)?

    var storefront: FullGameStorefront {
        FullGameStorefront(
            currentOwnership: { await self.resolve() },
            observeUpdates: { self.receiveUpdate = $0 },
            recoverUnfinished: { receive in
                let transactions = self.unfinished
                self.unfinished.removeAll()
                for transaction in transactions {
                    await receive(transaction)
                }
            },
            loadProduct: { nil },
            sync: {
                if let syncError = self.syncError {
                    throw syncError
                }
            },
        )
    }

    func waitForUpdateReceiver() async throws -> FullGameStorefront.Receive {
        while receiveUpdate == nil {
            try await Task.sleep(for: .milliseconds(5))
        }
        return try #require(receiveUpdate, "Transaction listener did not start")
    }

    func waitForRead(count: Int) async throws {
        while readCount < count {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func resolve() async -> FullGameStore.Ownership {
        readCount += 1
        if let nextRead {
            self.nextRead = nil
            var iterator = nextRead.makeAsyncIterator()
            return await iterator.next() ?? .free
        }
        return ownership
    }
}
