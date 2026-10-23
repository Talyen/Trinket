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

    public enum Outcome: Equatable, Sendable {
        case pricingUnavailable
        case pendingApproval
        case restoreFailed
        case noPurchaseFound
        case purchaseUnverified
        case purchaseFailed
    }

    public nonisolated static let productID = "com.ryanmcintire.Trinket.fullgame"
    public private(set) var ownership: Ownership = .checking
    public private(set) var outcome: Outcome?
    public private(set) var product: Product?
    public private(set) var isLoading = false
    public private(set) var isPurchasing = false
    public private(set) var isRestoring = false
    @ObservationIgnored private var listener: Task<Void, Never>?
    private var revision = 0
    private var outcomeRevision = 0
    private let storefront: FullGameStorefront

    public convenience init() {
        self.init(storefront: .system)
    }

    init(storefront: FullGameStorefront) {
        self.storefront = storefront
    }

    #if DEBUG
    /// Ephemeral access for gameplay inspection; never creates a StoreKit transaction.
    static func developmentUnlocked() -> FullGameStore {
        let store = FullGameStore(storefront: FullGameStorefront(
            currentOwnership: { .purchased },
            observeUpdates: { _ in },
            recoverUnfinished: { _ in },
            loadProduct: { nil },
            sync: {},
        ))
        store.ownership = .purchased
        return store
    }
    #endif

    deinit {
        listener?.cancel()
    }

    public func start() async {
        if listener == nil {
            let storefront = storefront
            listener = Task { [weak self] in
                await storefront.observeUpdates { [weak self] transaction in
                    await self?.receive(transaction)
                }
            }
        }
        // The view's startup task can be cancelled while the app-lifetime
        // listener survives. A later presentation must still recover ownership.
        await refreshOwnership()
        await storefront.recoverUnfinished { [weak self] transaction in
            await self?.receive(transaction)
        }
    }

    public func loadProduct() async {
        guard !isLoading, product == nil else { return }
        let startedAt = beginOutcomeOperation()
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await storefront.loadProduct()
        } catch {
            product = nil
        }
        if product == nil, !ownership.access.hasFullGame {
            publishOutcome(.pricingUnavailable, revision: startedAt)
        }
    }

    public func refreshOwnership() async {
        _ = await reconcileOwnership()
    }

    private func reconcileOwnership() async -> Bool {
        revision &+= 1
        let startedAt = revision
        let resolved = await storefront.currentOwnership()
        guard revision == startedAt, !Task.isCancelled else { return false }
        ownership = resolved
        if resolved.access.hasFullGame {
            _ = beginOutcomeOperation()
        }
        return true
    }

    @discardableResult
    public func purchaseStarted() -> Bool {
        guard !isPurchasing, !isRestoring, !ownership.access.hasFullGame else { return false }
        _ = beginOutcomeOperation()
        isPurchasing = true
        return true
    }

    public func purchaseCompleted(_ result: Result<Product.PurchaseResult, any Error>) async {
        let startedAt = outcomeRevision
        defer { isPurchasing = false }
        switch result {
        case let .success(.success(verification)):
            if let transaction = FullGameStorefront.delivery(verification) {
                await receive(transaction)
                if case .unverified = verification, !ownership.access.hasFullGame {
                    publishOutcome(.purchaseUnverified, revision: startedAt)
                } else if ownership == .unverified {
                    publishOutcome(.purchaseUnverified, revision: startedAt)
                }
            }
        case .success(.pending):
            if !ownership.access.hasFullGame {
                publishOutcome(.pendingApproval, revision: startedAt)
            }
        case .failure(StoreKitError.userCancelled), .failure(is CancellationError):
            break
        case .failure:
            if !ownership.access.hasFullGame {
                publishOutcome(.purchaseFailed, revision: startedAt)
            }
        case .success:
            break
        }
    }

    public func restore() async {
        guard !isRestoring, !isPurchasing else { return }
        let startedAt = beginOutcomeOperation()
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await storefront.sync()
        } catch StoreKitError.userCancelled {
            return
        } catch {
            publishOutcome(.restoreFailed, revision: startedAt)
            return
        }
        guard await reconcileOwnership() else { return }
        switch ownership {
        case .free:
            publishOutcome(.noPurchaseFound, revision: startedAt)
        case .unverified:
            publishOutcome(.purchaseUnverified, revision: startedAt)
        case .checking, .purchased, .familyShared:
            break
        }
    }

    private func beginOutcomeOperation() -> Int {
        outcomeRevision &+= 1
        outcome = nil
        return outcomeRevision
    }

    private func publishOutcome(_ value: Outcome, revision: Int) {
        guard outcomeRevision == revision, !Task.isCancelled else { return }
        outcome = value
    }

    private func receive(_ transaction: FullGameTransaction) async {
        // Deliveries are notifications, not ownership snapshots. Re-read the
        // current entitlement set even for old unfinished or unverified events.
        // Superseded/cancelled reads leave verified delivery unfinished for retry.
        guard await reconcileOwnership() else { return }
        await transaction.finish?()
    }
}
