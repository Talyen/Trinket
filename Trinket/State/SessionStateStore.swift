import Foundation

/// Ephemeral UI session state stored in `UserDefaults` (tab selection, map scroll,
/// in-flight battle restoration). Cloud-synced gameplay progress lives in `PlayerSave`.
@Observable
final class SessionStateStore {
    private let defaults: UserDefaults

    var selectedTab: AppTab? {
        didSet { defaults.set(selectedTab?.rawValue, forKey: Self.tabKey) }
    }

    var activeBattleStageID: String? {
        didSet { defaults.set(activeBattleStageID, forKey: Self.activeBattleStageIDKey) }
    }

    var mapScrollStageID: String? {
        didSet { defaults.set(mapScrollStageID, forKey: Self.mapScrollStageIDKey) }
    }

    private(set) var mapScrollNonce: UInt = 0

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Self.tabKey) {
            selectedTab = AppTab(rawValue: raw)
        }
        activeBattleStageID = defaults.string(forKey: Self.activeBattleStageIDKey)
        mapScrollStageID = defaults.string(forKey: Self.mapScrollStageIDKey)
    }

    func clearBattleState() {
        activeBattleStageID = nil
        mapScrollStageID = nil
    }

    func clearAll() {
        selectedTab = nil
        activeBattleStageID = nil
        mapScrollStageID = nil
        mapScrollNonce = 0
    }

    func noteMapScrollFocus(_ targetID: String, bumpEvenWhenUnchanged: Bool = false) {
        let shouldBump = bumpEvenWhenUnchanged || mapScrollStageID != targetID
        mapScrollStageID = targetID
        if shouldBump {
            mapScrollNonce &+= 1
        }
    }

    private static let tabKey = "session.selectedTab"
    private static let activeBattleStageIDKey = "session.activeBattleStageID"
    private static let mapScrollStageIDKey = "session.mapScrollStageID"
}
