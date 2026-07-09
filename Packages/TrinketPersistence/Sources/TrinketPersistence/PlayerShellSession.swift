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
    /// Fingerprint of the last Homestead actionable set the player acknowledged by visiting Homestead.
    /// Empty means no acknowledgment yet. Ephemeral affordance dismiss — not CloudKit player-save data.
    public var acknowledgedHomesteadActionableFingerprint: String = ""
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
