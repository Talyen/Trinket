import Foundation
import StoreKit
import Testing
@testable import TrinketAppState

@Suite("Full Game StoreKit", .serialized)
struct FullGameStoreTests {
    @Test @MainActor
    func `an older entitlement refresh cannot revoke a newer restored purchase`() async {
        let store = FullGameStore()
        let response = AsyncStream<FullGameStore.Ownership>.makeStream()
        var firstReadStarted = false
        let first = Task {
            await store.refreshOwnership {
                firstReadStarted = true
                var iterator = response.stream.makeAsyncIterator()
                return await iterator.next() ?? .free
            }
        }
        while !firstReadStarted {
            await Task.yield()
        }

        await store.refreshOwnership { .purchased }
        #expect(store.ownership.access.hasFullGame)
        response.continuation.yield(.free)
        response.continuation.finish()
        await first.value

        #expect(store.ownership == .purchased)
        #expect(store.ownership.access.hasFullGame)
    }

    @Test @MainActor
    func `cancelling and pending never grant access`() async {
        let store = FullGameStore()
        store.purchaseStarted()
        await store.purchaseCompleted(.success(.userCancelled))
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isPurchasing)
        store.purchaseStarted()
        await store.purchaseCompleted(.success(.pending))
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isPurchasing)
        store.purchaseStarted()
        await store.purchaseCompleted(.failure(StoreKitError.networkError(URLError(.notConnectedToInternet))))
        #expect(!store.ownership.access.hasFullGame)
        #expect(!store.isPurchasing)
    }
}
