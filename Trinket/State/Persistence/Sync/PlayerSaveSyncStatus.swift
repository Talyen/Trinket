import Foundation

enum PlayerSaveAccountStatus: Equatable {
    case available
    case unavailable(String)
}

enum PlayerSaveSyncStatus: Equatable {
    case idle
    case syncing
    case upToDate
    case offline
    case iCloudUnavailable(String)
    case error(String)

    var displayText: String {
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
