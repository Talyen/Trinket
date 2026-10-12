import Foundation
import Observation
import TrinketCore

/// Owns a surface's replaceable artwork working set across asynchronous preparation.
@MainActor
@Observable
public final class PreparedArtworkPinSet {
    public struct Update: Sendable {
        fileprivate let ownerID: UUID
        fileprivate let generation: UInt64
        fileprivate let desired: Set<String>
    }

    public private(set) var names: Set<String> = []
    @ObservationIgnored private let ownerID = UUID()
    @ObservationIgnored private var generation: UInt64 = 0
    @ObservationIgnored private let acquire: (Set<String>) async -> Set<String>
    @ObservationIgnored private let releasePins: @MainActor @Sendable (Set<String>) -> Void

    public convenience init() {
        self.init(
            acquire: { await Set(PreparedArtworkCache.shared.acquirePinnedArtwork(names: Array($0))) },
            release: { PreparedArtworkCache.shared.releasePins(names: Array($0)) },
        )
    }

    init(
        acquire: @escaping (Set<String>) async -> Set<String>,
        release: @escaping @MainActor @Sendable (Set<String>) -> Void,
    ) {
        self.acquire = acquire
        releasePins = release
    }

    deinit {
        // The observation accessor is actor-isolated; teardown copies its stored value.
        let names = _names
        let releasePins = releasePins
        MainActorCleanup.perform { releasePins(names) }
    }

    /// Returns nil for cancelled or superseded work. Outgoing pins can survive
    /// publication until the surface finishes its transition with `finish`.
    @discardableResult
    public func prepare(
        names desiredNames: [String],
        retainingOutgoing: Bool = false,
        isCurrent: () -> Bool = { true },
    ) async -> Update? {
        generation &+= 1
        let request = generation
        guard !Task.isCancelled else { return nil }
        let desired = Set(desiredNames)
        let added = desired.subtracting(names)
        let acquired = added.isEmpty ? [] : await acquire(added)
        guard !Task.isCancelled, request == generation, isCurrent() else {
            releasePins(acquired)
            return nil
        }
        names.formUnion(acquired)
        let update = Update(ownerID: ownerID, generation: request, desired: desired)
        if !retainingOutgoing {
            finish(update)
        }
        return update
    }

    /// An obsolete transition cannot release a newer presentation's pins.
    @discardableResult
    public func finish(_ update: Update) -> Bool {
        guard update.ownerID == ownerID, update.generation == generation else { return false }
        releasePins(names.subtracting(update.desired))
        names.formIntersection(update.desired)
        return true
    }

    /// Prune without acquiring artwork, invalidating any in-flight replacement.
    public func retain(names desiredNames: Set<String>) {
        generation &+= 1
        releasePins(names.subtracting(desiredNames))
        names.formIntersection(desiredNames)
    }

    public func release() {
        retain(names: [])
    }
}
