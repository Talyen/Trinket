import StoreKit

/// Only verified Full Game deliveries carry permission to acknowledge StoreKit.
/// Ownership is resolved separately from the current entitlement set.
struct FullGameTransaction: Sendable {
    let finish: (@Sendable () async -> Void)?
}

/// StoreKit I/O capabilities; FullGameStore owns ordering and access publication.
@MainActor
struct FullGameStorefront {
    typealias Receive = @MainActor (FullGameTransaction) async -> Void

    var currentOwnership: @Sendable () async -> FullGameStore.Ownership
    var observeUpdates: (@escaping Receive) async -> Void
    var recoverUnfinished: (@escaping Receive) async -> Void
    var loadProduct: () async throws -> Product?
    var sync: () async throws -> Void

    static let system = Self(
        currentOwnership: resolveCurrentOwnership,
        observeUpdates: { receive in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                if let transaction = delivery(result) {
                    await receive(transaction)
                }
            }
        },
        recoverUnfinished: { receive in
            for await result in Transaction.unfinished {
                guard !Task.isCancelled else { return }
                if let transaction = delivery(result) {
                    await receive(transaction)
                }
            }
        },
        loadProduct: {
            try await Product.products(for: [FullGameStore.productID]).first { $0.id == FullGameStore.productID }
        },
        sync: { try await AppStore.sync() },
    )

    static func delivery(_ result: VerificationResult<Transaction>) -> FullGameTransaction? {
        switch result {
        case let .verified(transaction) where transaction.productID == FullGameStore.productID:
            FullGameTransaction(finish: { await transaction.finish() })
        case let .unverified(transaction, _) where transaction.productID == FullGameStore.productID:
            FullGameTransaction(finish: nil)
        default:
            nil
        }
    }

    @concurrent
    private nonisolated static func resolveCurrentOwnership() async -> FullGameStore.Ownership {
        var resolved = FullGameStore.Ownership.free
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction) where transaction.productID == FullGameStore.productID && transaction.revocationDate == nil:
                resolved = transaction.ownershipType == .familyShared ? .familyShared : .purchased
            case let .unverified(transaction, _) where transaction.productID == FullGameStore.productID:
                if resolved == .free {
                    resolved = .unverified
                }
            default:
                break
            }
        }
        return resolved
    }
}
