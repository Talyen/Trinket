import BattleEngine
import TrinketCore
import TrinketFeatureContracts

/// Sole owner of prepared handles, selection, and their preview projection.
@MainActor
final class PreparedBattleRegistry {
    @MainActor
    struct Entry {
        let registration: PlayBattleRunRegistration
        let handle: any PreparedBattleRunHandle
    }

    private var entriesStorage: [BattleRunKey: Entry] = [:]
    private var selectedKey: BattleRunKey?
    var entries: [BattleRunKey: Entry] {
        entriesStorage
    }

    deinit {
        let entries = entriesStorage
        MainActorCleanup.perform {
            for entry in entries.values {
                entry.handle.invalidate()
            }
        }
    }

    func install(_ entry: Entry, for key: BattleRunKey) {
        if let previous = entriesStorage[key], previous.handle !== entry.handle {
            previous.handle.invalidate()
        }
        entriesStorage[key] = entry
    }

    /// Activation transfers the matched resource to the runtime only on success.
    func consume(_ key: BattleRunKey) {
        entriesStorage[key] = nil
        if selectedKey == key {
            selectedKey = nil
        }
    }

    @discardableResult
    func select(_ key: BattleRunKey?) -> Bool {
        guard selectedKey != key else { return false }
        selectedKey = key
        return true
    }

    func retain(where keep: (BattleRunKey, Entry) -> Bool) {
        entriesStorage = entriesStorage.filter { key, entry in
            if keep(key, entry) {
                return true
            }
            entry.handle.invalidate()
            return false
        }
        if let selectedKey, entriesStorage[selectedKey] == nil {
            self.selectedKey = nil
        }
    }

    var preview: BattlePreparedPreview {
        let selected = selectedKey.flatMap { entriesStorage[$0]?.handle }
            ?? (entriesStorage.count == 1 ? entriesStorage.values.first?.handle : nil)
        let configurations = entriesStorage.count <= 1
            ? entriesStorage.values.map(\.registration.launch.configuration)
            : entriesStorage.sorted { $0.key.rawValue < $1.key.rawValue }.map(\.value.registration.launch.configuration)
        return BattlePreparedPreview(configurations: configurations, selected: selected)
    }
}

/// Claim state cannot outlive or become detached from its launch registration.
@MainActor
final class ActivePlayBattle {
    enum ClaimState {
        case unclaimed
        case claiming
        case defeat
        case victory(onFinished: () -> Void)
        case ending
    }

    let registration: PlayBattleRunRegistration
    var claimState: ClaimState = .unclaimed

    var canRestart: Bool {
        switch claimState {
        case .unclaimed, .defeat: true
        case .claiming, .victory, .ending: false
        }
    }

    func releaseClaim() {
        if case .claiming = claimState {
            claimState = .unclaimed
        }
    }

    init(_ registration: PlayBattleRunRegistration) {
        self.registration = registration
    }
}
