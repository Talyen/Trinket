import Foundation
import StoreKit
import Testing
@testable import TrinketAppState

@Suite("Full Game StoreKit", .serialized)
struct FullGameStoreTests {
    @Test @MainActor
    func `cancelling and pending never grant access`() async {
        let store = FullGameStore()
        store.purchaseStarted()
        await store.purchaseCompleted(.success(.userCancelled))
        #expect(!store.ownership.access.hasFullGame)
        #expect(store.message == nil)
        #expect(!store.isPurchasing)
        store.purchaseStarted()
        await store.purchaseCompleted(.success(.pending))
        #expect(!store.ownership.access.hasFullGame)
        #expect(store.message != nil)
        #expect(!store.isPurchasing)
        store.purchaseStarted()
        await store.purchaseCompleted(.failure(StoreKitError.networkError(URLError(.notConnectedToInternet))))
        #expect(!store.ownership.access.hasFullGame)
        #expect(store.message != nil)
    }
}
