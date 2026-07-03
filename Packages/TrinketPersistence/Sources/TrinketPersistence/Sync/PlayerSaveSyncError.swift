import Foundation

public enum PlayerSaveSyncError: Error, Equatable {
    case recordConflict(RemotePlayerSave)
}
