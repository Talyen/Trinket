import Foundation
import TrinketContent

/// Unknown payloads remain opaque through snapshots, recovery and graph writes.
public struct PlayerLibraryState: Codable, Equatable, Sendable {
    public private(set) var progress = LibraryProgress()
    public private(set) var unreadablePayload: Data?
    public var isReadable: Bool {
        unreadablePayload == nil
    }

    public init() {}

    public init(payload: Data?) {
        guard let payload else { return }
        do {
            var value = try JSONDecoder().decode(LibraryProgress.self, from: payload)
            guard value.version == 1, value.backfillVersion >= 0 else {
                unreadablePayload = payload
                return
            }
            value.merge(value)
            progress = value
        } catch {
            unreadablePayload = payload
        }
    }

    public func encodedPayload() throws -> Data {
        if let unreadablePayload {
            return unreadablePayload
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try encoder.encode(progress)
    }

    public init(from decoder: any Decoder) throws {
        try self.init(payload: decoder.singleValueContainer().decode(Data.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(encodedPayload())
    }

    mutating func encounter(_ id: String) {
        guard isReadable else { return }
        progress.encounter(id)
    }

    mutating func defeat(_ id: String) {
        guard isReadable else { return }
        progress.defeat(id)
    }

    mutating func merge(_ other: Self) {
        guard isReadable, other.isReadable else {
            if !other.isReadable {
                self = other
            }
            return
        }
        progress.merge(other.progress)
    }

    mutating func reconcile(in save: PlayerSave) {
        guard isReadable else { return }
        if progress.backfillVersion < 1 {
            for id in LibraryLegacyHistory.defeatedEnemyIDs(in: save) {
                progress.defeat(id)
            }
            progress.backfillVersion = 1
        }
        progress.evaluate(
            libraryTier: save.homestead.tier(for: .library),
        )
    }
}

enum LibraryResearchMutation {
    static func reconcile(_ save: inout PlayerSave, previous: PlayerSave? = nil) {
        if let previous,
           previous.library == save.library,
           previous.homestead.tier(for: .library) == save.homestead.tier(for: .library) {
            return
        }
        var library = save.library
        library.reconcile(in: save)
        save.library = library
    }
}
