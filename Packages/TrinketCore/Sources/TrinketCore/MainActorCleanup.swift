import Foundation

/// Releases actor-owned resources inline on the main thread, or on its next turn.
public final class MainActorCleanup: Sendable {
    private let action: @MainActor @Sendable () -> Void

    public init(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    public static func perform(_ action: @escaping @MainActor @Sendable () -> Void) {
        if Thread.isMainThread {
            MainActor.assumeIsolated { action() }
        } else {
            Task { @MainActor in action() }
        }
    }

    deinit {
        Self.perform(action)
    }
}
