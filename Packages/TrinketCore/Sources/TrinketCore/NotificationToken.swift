import Foundation

/// RAII wrapper for block-based `NotificationCenter` observers.
/// Removes the observer when deallocated (Apple-recommended lifecycle pattern).
// Concurrency-Safety: @unchecked Sendable — immutable after init; only the owning
// `@MainActor` client retains the token, and `deinit` solely unregisters the observer.
public final class NotificationToken: @unchecked Sendable {
    private let center: NotificationCenter
    private let token: any NSObjectProtocol

    public init(center: NotificationCenter, token: any NSObjectProtocol) {
        self.center = center
        self.token = token
    }

    deinit {
        center.removeObserver(token)
    }
}

public extension NotificationCenter {
    /// Registers a block observer and returns a token that unregisters on deallocation.
    func observe(
        name: Notification.Name?,
        object obj: Any? = nil,
        queue: OperationQueue? = nil,
        using block: @escaping @Sendable (Notification) -> Void
    ) -> NotificationToken {
        let token = addObserver(forName: name, object: obj, queue: queue, using: block)
        return NotificationToken(center: self, token: token)
    }
}
