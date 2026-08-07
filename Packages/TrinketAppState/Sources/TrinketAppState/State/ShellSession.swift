import Foundation
import Observation

/// In-session shell navigation state.
///
/// The selected tab is launch-argument driven and intentionally not persisted:
/// every cold launch lands on Play unless a UI-test launch override selects
/// another tab/screen. Legacy UserDefaults shell keys are cleared on reset and
/// never restored.
@MainActor
@Observable
public final class ShellSession {
    public var selectedTab: AppTab = .play

    public init(selectedTab: AppTab = .play) {
        self.selectedTab = selectedTab
    }

    public static let legacySessionTabKey = "session.selectedTab"
    private static let legacyDiscardedKeys = [
        "session.activeBattleStageID",
        "session.mapScrollStageID",
        "session.activeBattleSavedAt",
        "session.activeBattleSchemaVersion",
        "session.lastBackgroundedTime",
        "session.viewedCombatantIDs",
    ]

    /// Discarded battle-resume / map-scroll keys — cleared on reset, never restored.
    public static func clearLegacyKeys(from defaults: UserDefaults) {
        defaults.removeObject(forKey: legacySessionTabKey)
        for key in legacyDiscardedKeys {
            defaults.removeObject(forKey: key)
        }
    }
}
