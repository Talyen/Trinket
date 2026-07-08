import Foundation

public enum PlayerSavePersistenceError: Error, Equatable {
    case writeFailed
    case invalidSave(String)
    case storeUnavailable(String)
}
