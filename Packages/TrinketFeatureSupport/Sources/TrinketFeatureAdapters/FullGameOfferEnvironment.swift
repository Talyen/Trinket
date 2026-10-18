import SwiftUI
import TrinketFeatureContracts

/// A retained offer request whose identity stays stable across presentation updates.
public struct FullGameOfferRequestAction: Equatable, Sendable {
    @MainActor
    private final class Storage {
        let perform: @MainActor (FullGameOfferOrigin) -> Void

        init(perform: @escaping @MainActor (FullGameOfferOrigin) -> Void) {
            self.perform = perform
        }
    }

    private let storage: Storage?

    /// Creates an inert action for a subtree without an offer host.
    public nonisolated init() {
        storage = nil
    }

    /// Create once in the presentation owner and reuse the value when injecting it.
    @MainActor
    public init(_ perform: @escaping @MainActor (FullGameOfferOrigin) -> Void) {
        storage = Storage(perform: perform)
    }

    @MainActor
    public func callAsFunction(_ origin: FullGameOfferOrigin) {
        storage?.perform(origin)
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage === rhs.storage
    }
}

public extension EnvironmentValues {
    @Entry var requestFullGameOffer = FullGameOfferRequestAction()
}
