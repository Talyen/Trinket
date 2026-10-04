import Observation
import StoreKit
import TrinketContent

@MainActor
@Observable
public final class FullGameStore {
    public enum Ownership: Equatable, Sendable {
        case checking
        case free
        case purchased
        case familyShared
        case unverified

        public var access: ContentAccessPolicy {
            self == .purchased || self == .familyShared ? .fullGame : .free
        }
    }

    public nonisolated static let productID = "com.ryanmcintire.Trinket.fullgame"
    public private(set) var ownership: Ownership = .checking
    public private(set) var product: Product?
    public private(set) var isLoading = false
    public private(set) var isPurchasing = false
    public private(set) var isRestoring = false
    private var listener: Task<Void, Never>?
    private var revision = 0

    public init() {}

    isolated deinit {
        listener?.cancel()
    }

    public func start() async {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            for await result in Transaction.updates {
                guard !Task.isCancelled else { return }
                await self?.receive(result)
            }
        }
        await refreshOwnership()
        for await result in Transaction.unfinished {
            await receive(result)
        }
    }

    public func loadProduct() async {
        guard !isLoading, product == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await Product.products(for: [Self.productID]).first { $0.id == Self.productID }
        } catch {
            product = nil
        }
    }

    public func refreshOwnership() async {
        await refreshOwnership(resolve: Self.resolveCurrentOwnership)
    }

    func refreshOwnership(resolve: () async -> Ownership) async {
        revision &+= 1
        let startedAt = revision
        // Entitlement enumeration can block on I/O; resolve off the main actor
        // and hop back only to publish.
        let resolved = await resolve()
        guard revision == startedAt, !Task.isCancelled else { return }
        ownership = resolved
    }

    /// Reads the current entitlement set off the main actor.
    private nonisolated static func resolveCurrentOwnership() async -> Ownership {
        var resolved = Ownership.free
        for await result in Transaction.currentEntitlements {
            switch result {
            case let .verified(transaction) where transaction.productID == Self.productID && transaction.revocationDate == nil:
                resolved = transaction.ownershipType == .familyShared ? .familyShared : .purchased
            case let .unverified(transaction, _) where transaction.productID == Self.productID:
                if resolved == .free {
                    resolved = .unverified
                }
            default:
                break
            }
        }
        return resolved
    }

    public func purchaseStarted() {
        isPurchasing = true
    }

    public func purchaseCompleted(_ result: Result<Product.PurchaseResult, any Error>) async {
        defer { isPurchasing = false }
        switch result {
        case let .success(.success(verification)):
            await receive(verification)
        case .success, .failure:
            break
        }
    }

    public func restore() async {
        guard !isRestoring, !isPurchasing else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
        } catch {
            return
        }
        await refreshOwnership()
    }

    private func receive(_ result: VerificationResult<Transaction>) async {
        switch result {
        case let .verified(transaction):
            guard transaction.productID == Self.productID else { return }
            revision &+= 1
            if transaction.revocationDate != nil {
                await refreshOwnership()
            } else {
                ownership = transaction.ownershipType == .familyShared ? .familyShared : .purchased
            }
            await transaction.finish()
        case .unverified:
            break
        }
    }
}
