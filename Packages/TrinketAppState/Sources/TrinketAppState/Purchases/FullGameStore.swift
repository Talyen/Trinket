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
    @ObservationIgnored private var listener: Task<Void, Never>?
    private var revision = 0
    private let storefront: FullGameStorefront

    public convenience init() {
        self.init(storefront: .system)
    }

    init(storefront: FullGameStorefront) {
        self.storefront = storefront
    }

    deinit {
        listener?.cancel()
    }

    public func start() async {
        guard listener == nil else { return }
        let storefront = storefront
        listener = Task { [weak self] in
            await storefront.observeUpdates { [weak self] transaction in
                await self?.receive(transaction)
            }
        }
        await refreshOwnership()
        await storefront.recoverUnfinished { [weak self] transaction in
            await self?.receive(transaction)
        }
    }

    public func loadProduct() async {
        guard !isLoading, product == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            product = try await storefront.loadProduct()
        } catch {
            product = nil
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
        return true
    }

    public func purchaseStarted() {
        isPurchasing = true
    }

    public func purchaseCompleted(_ result: Result<Product.PurchaseResult, any Error>) async {
        defer { isPurchasing = false }
        switch result {
        case let .success(.success(verification)):
            if let transaction = FullGameStorefront.delivery(verification) {
                await receive(transaction)
            }
        case .success, .failure:
            break
        }
    }

    public func restore() async {
        guard !isRestoring, !isPurchasing else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await storefront.sync()
        } catch {
            return
        }
        await refreshOwnership()
    }

    private func receive(_ transaction: FullGameTransaction) async {
        // Deliveries are notifications, not ownership snapshots. Re-read the
        // current entitlement set even for old unfinished or unverified events.
        // Superseded/cancelled reads leave verified delivery unfinished for retry.
        guard await reconcileOwnership() else { return }
        await transaction.finish?()
    }
}
