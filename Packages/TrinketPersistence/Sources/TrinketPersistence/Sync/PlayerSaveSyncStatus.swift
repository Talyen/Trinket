import Foundation

public enum PlayerSaveAccountStatus: Equatable, Sendable {
    case available
    case unavailable(String)
}

public enum PlayerSaveSyncStatus: Equatable, Sendable {
    case idle
    case syncing
    case upToDate
    case offline
    case iCloudUnavailable(String)
    case error(String)

    public var displayText: String {
        switch self {
        case .idle:
            return "Checking iCloud…"
        case .syncing:
            return "Syncing progress…"
        case .upToDate:
            return "Progress synced with iCloud"
        case .offline:
            return "Playing offline. Progress saves on this device."
        case let .iCloudUnavailable(message):
            return message
        case let .error(message):
            return "Couldn't sync. \(message)"
        }
    }
}
