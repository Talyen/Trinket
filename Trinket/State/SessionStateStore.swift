import Foundation
import TrinketPersistence

/// Ephemeral UI session state stored in `UserDefaults` (tab selection, map scroll,
/// in-flight battle restoration). Cloud-synced gameplay progress lives in `PlayerSave`.
@Observable
final class SessionStateStore {
    private let defaults: UserDefaults

    static let currentSchemaVersion = 1

    var selectedTab: AppTab? {
        didSet { defaults.set(selectedTab?.rawValue, forKey: Self.tabKey) }
    }

    var activeBattleStageID: String? {
        didSet {
            defaults.set(activeBattleStageID, forKey: Self.activeBattleStageIDKey)
            if activeBattleStageID != nil {
                let now = Date()
                activeBattleSavedAt = now
                defaults.set(now.timeIntervalSince1970, forKey: Self.activeBattleSavedAtKey)
                activeBattleSchemaVersion = Self.currentSchemaVersion
                defaults.set(Self.currentSchemaVersion, forKey: Self.activeBattleSchemaVersionKey)
            } else {
                activeBattleSavedAt = nil
                defaults.removeObject(forKey: Self.activeBattleSavedAtKey)
                activeBattleSchemaVersion = nil
                defaults.removeObject(forKey: Self.activeBattleSchemaVersionKey)
            }
        }
    }

    var activeBattleSavedAt: Date?
    var activeBattleSchemaVersion: Int?
    var lastBackgroundedTime: Date? {
        didSet {
            if let lastBackgroundedTime {
                defaults.set(lastBackgroundedTime.timeIntervalSince1970, forKey: Self.lastBackgroundedTimeKey)
            } else {
                defaults.removeObject(forKey: Self.lastBackgroundedTimeKey)
            }
        }
    }

    var viewedCombatantIDs: Set<String> {
        didSet {
            defaults.set(Array(viewedCombatantIDs), forKey: Self.viewedCombatantIDsKey)
        }
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

        if let savedAtVal = defaults.object(forKey: Self.activeBattleSavedAtKey) as? Double {
            activeBattleSavedAt = Date(timeIntervalSince1970: savedAtVal)
        }
        if let schemaVer = defaults.object(forKey: Self.activeBattleSchemaVersionKey) as? Int {
            activeBattleSchemaVersion = schemaVer
        }
        if let lastBgVal = defaults.object(forKey: Self.lastBackgroundedTimeKey) as? Double {
            lastBackgroundedTime = Date(timeIntervalSince1970: lastBgVal)
        }
        if let viewedArray = defaults.stringArray(forKey: Self.viewedCombatantIDsKey) {
            viewedCombatantIDs = Set(viewedArray)
        } else {
            viewedCombatantIDs = []
        }
    }

    func markCombatantAsViewed(id: String) {
        if !viewedCombatantIDs.contains(id) {
            viewedCombatantIDs.insert(id)
        }
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
        lastBackgroundedTime = nil
        viewedCombatantIDs = []
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
    private static let activeBattleSavedAtKey = "session.activeBattleSavedAt"
    private static let activeBattleSchemaVersionKey = "session.activeBattleSchemaVersion"
    private static let lastBackgroundedTimeKey = "session.lastBackgroundedTime"
    private static let viewedCombatantIDsKey = "session.viewedCombatantIDs"
}
