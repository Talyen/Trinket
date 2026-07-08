import Foundation
import SwiftData

@Model
public final class PlayerShellSession {
    public var id: String = "current"
    public var selectedTabRaw: String = "play"
    public var activeBattleStageID: String?
    public var mapScrollStageID: String?
    public var activeBattleSavedAt: Date?
    public var activeBattleSchemaVersion: Int?
    public var lastBackgroundedTime: Date?
    public var viewedCombatantIDs: [String] = []
    public var updatedAt: Date = .now

    public init(id: String = "current") {
        self.id = id
    }
}

public enum PlayerShellSessionTab: String, CaseIterable, Sendable {
    case play
    case collection
    case homestead
    case search
    case options
}
