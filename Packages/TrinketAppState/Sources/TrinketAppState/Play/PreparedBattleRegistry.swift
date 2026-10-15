import BattleEngine
import TrinketCore
import TrinketFeatureContracts

/// Sole owner of prepared handles, selection, and their preview projection.
@MainActor
final class PreparedBattleRegistry {
    struct Entry {
        let registration: PlayBattleRunRegistration
        let handle: any PreparedBattleRunHandle
    }

    @MainActor
    private final class Storage {
        var entries: [BattleRunKey: Entry] = [:]

        func invalidateAll() {
            for entry in entries.values {
                entry.handle.invalidate()
            }
            entries.removeAll()
        }
    }

    private let storage = Storage()
    private var selectedKey: BattleRunKey?
    var entries: [BattleRunKey: Entry] {
        storage.entries
    }

    deinit {
        let storage = storage
        MainActorCleanup.perform { storage.invalidateAll() }
    }

    func install(_ entry: Entry, for key: BattleRunKey) {
        if let previous = entries[key], previous.handle !== entry.handle {
            previous.handle.invalidate()
        }
        storage.entries[key] = entry
    }

    /// Activation transfers the matched resource to the runtime only on success.
    func consume(_ key: BattleRunKey) {
        storage.entries[key] = nil
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
        storage.entries = entries.filter { key, entry in
            if keep(key, entry) {
                return true
            }
            entry.handle.invalidate()
            return false
        }
        if let selectedKey, entries[selectedKey] == nil {
            self.selectedKey = nil
        }
    }

    var preview: BattlePreparedPreview {
        let runs = entries.sorted { $0.key.rawValue < $1.key.rawValue }.map(\.value)
        let selected = selectedKey.flatMap { entries[$0]?.handle }
            ?? (runs.count == 1 ? runs.first?.handle : nil)
        return BattlePreparedPreview(configurations: runs.map(\.registration.launch.configuration), selected: selected)
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
