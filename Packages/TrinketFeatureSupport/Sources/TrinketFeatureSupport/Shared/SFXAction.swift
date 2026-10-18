import SwiftUI

/// A retained sound action whose identity stays stable across presentation updates.
public struct SFXAction: Equatable, Sendable {
    @MainActor
    private final class Storage {
        let perform: @MainActor (String, Double) -> Void

        init(perform: @escaping @MainActor (String, Double) -> Void) {
            self.perform = perform
        }
    }

    private let storage: Storage?

    /// Creates an inert action for a subtree without a sound owner.
    public nonisolated init() {
        storage = nil
    }

    /// Create once in the presentation owner and reuse the value when injecting it.
    @MainActor
    public init(_ perform: @escaping @MainActor (String, Double) -> Void) {
        storage = Storage(perform: perform)
    }

    @MainActor
    public func callAsFunction(_ id: String, _ volume: Double) {
        storage?.perform(id, volume)
    }

    public nonisolated static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.storage === rhs.storage
    }
}

public extension EnvironmentValues {
    @Entry var playSFX = SFXAction()
}
