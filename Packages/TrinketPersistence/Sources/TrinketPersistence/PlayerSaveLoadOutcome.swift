import Foundation

public enum PlayerSaveLoadOutcome: Equatable {
    case missing
    case loaded(PlayerSave)
    case corrupt
}
