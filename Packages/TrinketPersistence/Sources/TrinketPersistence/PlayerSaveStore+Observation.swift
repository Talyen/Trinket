import Observation
import TrinketContent
import TrinketCore

public extension PlayerSaveStore {
    var journey: JourneyProgressState {
        observedValue(\.journey, from: \.journey)
    }

    var roster: PlayerRosterState {
        observedValue(\.roster, from: \.roster)
    }

    var inventory: PlayerInventoryState {
        observedValue(\.inventory, from: \.inventory)
    }

    var homestead: PlayerHomesteadState {
        observedValue(\.homestead, from: \.homestead)
    }

    var spires: PlayerSpiresState {
        observedValue(\.spires, from: \.spires)
    }

    var labyrinth: PlayerLabyrinthState {
        observedValue(\.labyrinth, from: \.labyrinth)
    }

    var voyage: PlayerVoyageState {
        observedValue(\.voyage, from: \.voyage)
    }

    var contracts: PlayerContractsState {
        observedValue(\.contracts, from: \.contracts)
    }

    var corruptionAltarCooldownRemaining: Int {
        observedValue(\.corruptionAltarCooldownRemaining, from: \.corruptionAltarCooldownRemaining)
    }

    var worldSeed: UInt64 {
        observedValue(\.worldSeed, from: \.worldSeed)
    }

    var starterSelection: StarterSelectionState {
        observedValue(\.starterSelection, from: \.starterSelection)
    }

    var sessionGeneration: UInt64 {
        observedValue(\.sessionGeneration, from: \.sessionGeneration)
    }

    /// The same complete value backs both transaction snapshots and narrow readers.
    var currentSave: PlayerSave {
        saveObservation.access(self, keyPath: \.currentSave)
        return observedSave
    }

    private func observedValue<Value>(
        _ property: KeyPath<PlayerSaveStore, Value>, from field: KeyPath<PlayerSave, Value>,
    ) -> Value {
        saveObservation.access(self, keyPath: property)
        return observedSave[keyPath: field]
    }

    /// Notify every affected reader before swapping the complete projection.
    /// Synchronous observers can read the old save, never a mixture of commits.
    internal func installObservedSave(_ save: PlayerSave, slices: PlayerSaveSlice = .all) {
        let before = observedSave
        var next = before
        for section in slices.sections {
            section.copy(from: save, into: &next)
        }
        if next.sessionGeneration != before.sessionGeneration {
            saveActionRetries.cancelAll()
        }

        var notifications: [(willSet: () -> Void, didSet: () -> Void)] = []
        func record<Value: Equatable>(
            _ property: KeyPath<PlayerSaveStore, Value>, _ field: KeyPath<PlayerSave, Value>,
        ) {
            guard before[keyPath: field] != next[keyPath: field] else { return }
            notifications.append((
                { self.saveObservation.willSet(self, keyPath: property) },
                { self.saveObservation.didSet(self, keyPath: property) },
            ))
        }
        for section in slices.sections {
            switch section {
            case .root:
                record(\.sessionGeneration, \.sessionGeneration)
                record(\.worldSeed, \.worldSeed)
                record(\.starterSelection, \.starterSelection)
                record(\.corruptionAltarCooldownRemaining, \.corruptionAltarCooldownRemaining)
            case .journey: record(\.journey, \.journey)
            case .roster: record(\.roster, \.roster)
            case .inventory: record(\.inventory, \.inventory)
            case .homestead: record(\.homestead, \.homestead)
            case .spires: record(\.spires, \.spires)
            case .labyrinth: record(\.labyrinth, \.labyrinth)
            case .contracts: record(\.contracts, \.contracts)
            case .voyage: record(\.voyage, \.voyage)
            }
        }
        // Bookkeeping-only writes still invalidate full-snapshot readers.
        if !notifications.isEmpty || before.schemaVersion != next.schemaVersion || before.modifiedAt != next.modifiedAt {
            notifications.append((
                { self.saveObservation.willSet(self, keyPath: \.currentSave) },
                { self.saveObservation.didSet(self, keyPath: \.currentSave) },
            ))
        }
        for notification in notifications {
            notification.willSet()
        }
        observedSave = next
        for notification in notifications.reversed() {
            notification.didSet()
        }
    }
}
