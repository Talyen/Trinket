import Foundation
import SwiftData

@Model
public final class PlayerShellSession {
    public var id: String = "current"
    public var selectedTabRaw: String = "play"
    public var activeBattleStageID: String?
    public var activeBattleAspectID: String?
    public var activeBattleAspectFloor: Int?
    public var activeBattleLabyrinthNodeID: String?
    public var mapScrollStageID: String?
    /// Last Play mode the player entered (campaign / aspects / labyrinth).
    public var lastPlayModeRaw: String = PlayerShellSessionPlayMode.campaign.rawValue
    public var activeBattleSavedAt: Date?
    public var activeBattleSchemaVersion: Int?
    public var lastBackgroundedTime: Date?
    public var updatedAt: Date = Date()

    public init(id: String = "current") {
        self.id = id
    }
}

public enum PlayerShellSessionTab: String, CaseIterable, Sendable {
    case play
    case collection
    case homestead
    case options
}

/// Peer Play destinations under the Mode Hub.
public enum PlayerShellSessionPlayMode: String, CaseIterable, Sendable {
    case campaign
    case aspects
    case labyrinth
}
