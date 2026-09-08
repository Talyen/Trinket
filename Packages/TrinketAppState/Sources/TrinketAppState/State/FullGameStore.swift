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

    public static let productID = "com.ryanmcintire.Trinket.fullgame"
    public private(set) var ownership: Ownership = .checking
    public private(set) var product: Product?
    public private(set) var isLoading = false
    public private(set) var isPurchasing = false
    public private(set) var isRestoring = false
    public private(set) var message: String?
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
            message = product == nil ? "Purchases are unavailable right now. Try again later." : nil
        } catch {
            message = "Couldn't load the purchase. Check your connection and try again."
        }
    }

    public func refreshOwnership() async {
        let startedAt = revision
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
        guard revision == startedAt, !Task.isCancelled else { return }
        ownership = resolved
        if resolved == .unverified {
            message = "Couldn't verify Full Game. Try Restore Purchases."
        }
    }

    public func purchaseStarted() {
        isPurchasing = true
        message = nil
    }

    public func purchaseCompleted(_ result: Result<Product.PurchaseResult, any Error>) async {
        defer { isPurchasing = false }
        switch result {
        case let .success(.success(verification)):
            await receive(verification)
        case .success(.pending):
            message = "Waiting for purchase approval. You can keep playing."
        case .success(.userCancelled):
            message = nil
        case .success:
            message = "The purchase hasn't completed. Try again later."
        case .failure:
            message = "Couldn't complete the purchase. Try again."
        }
    }

    public func restore() async {
        guard !isRestoring, !isPurchasing else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshOwnership()
            switch ownership {
            case .purchased, .familyShared:
                message = "Full Game restored."
            case .free:
                message = "No Full Game purchase was found for this Apple Account."
            case .checking, .unverified:
                message = "Couldn't verify the purchase. Try again later."
            }
        } catch StoreKitError.userCancelled {
            message = nil
        } catch {
            message = "Couldn't restore purchases. Check your connection and try again."
        }
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
                message = nil
            }
            await transaction.finish()
        case let .unverified(transaction, _):
            guard transaction.productID == Self.productID else { return }
            message = "Couldn't verify the purchase. Try Restore Purchases."
        }
    }
}
