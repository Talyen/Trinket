import Foundation

public struct PlayerAccountSessionToken: Equatable, Sendable {
    public let id: UUID

    public init(id: UUID = UUID()) {
        self.id = id
    }
}

/// Prevents concurrent authoritative sessions for one account.
/// Cloud sign-in can replace this with a server-backed lease.
public protocol PlayerAccountSessionLeasing: Sendable {
    func acquireSession() async throws -> PlayerAccountSessionToken
    func releaseSession(_ token: PlayerAccountSessionToken) async
}

/// Grants a single-device lease until explicit session close.
public struct LocalDeviceSessionLease: PlayerAccountSessionLeasing {
    public init() {}

    public func acquireSession() async throws -> PlayerAccountSessionToken {
        PlayerAccountSessionToken()
    }

    public func releaseSession(_: PlayerAccountSessionToken) async {}
}
