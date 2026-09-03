import Foundation

public enum PlayerSavePersistenceError: Error, Equatable, Sendable {
    case writeFailed
    case invalidSave(String)
    case storeUnavailable(String)
}
