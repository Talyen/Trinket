/// A rejected choice never writes; a failed durable commit may be retried.
public enum RosterEditResult: Equatable, Sendable {
    case committed
    case unavailable
    case persistenceFailed
}
