import Foundation
import TrinketCore

/// A checkpoint and ordered, immutable effects. A copied journal freezes a
/// request prefix; appends share immutable history without copying it.
struct CloudSaveJournal: Codable, Equatable, Sendable, Sequence {
    struct Record: Codable, Equatable, Sendable {
        let id: String
        let changedSliceMask: UInt16
        let before: CloudSaveSnapshotDelta?
        let after: CloudSaveSnapshotDelta
        let economy: CloudEconomicAction?
        let receipts: [SaveEconomicReceipt]?
        let actions: [ResolvedSaveAction.Record]?
        let collectionPositions: [HomesteadResource: UInt64]?
    }

    private(set) var id: String
    private(set) var checkpoint: CloudSaveSnapshot?
    private(set) var lastSnapshot: CloudSaveSnapshot?
    private var history = CloudSaveJournalRecords()
    private var hasActions = false

    init(_ mutations: [CloudSaveMutation] = []) {
        id = UUID().uuidString
        for mutation in mutations {
            append(mutation)
        }
    }

    var count: Int {
        history.count
    }

    var isEmpty: Bool {
        history.isEmpty
    }

    var records: CloudSaveJournalRecords {
        history
    }

    var first: CloudSaveMutation? {
        var iterator = makeIterator()
        return iterator.next()
    }

    mutating func append(_ mutation: CloudSaveMutation) {
        hasActions = hasActions || mutation.actions != nil
        let previous = lastSnapshot ?? mutation.before
        if checkpoint == nil {
            checkpoint = mutation.before
        }
        let gap = CloudSaveSnapshotDelta(from: previous, to: mutation.before)
        history.append(Record(
            id: mutation.id, changedSliceMask: mutation.changedSliceMask,
            before: gap.changes.isEmpty ? nil : gap,
            after: CloudSaveSnapshotDelta(from: mutation.before, to: mutation.after),
            economy: mutation.economy,
            receipts: mutation.receipts, actions: mutation.actions,
            collectionPositions: mutation.collectionPositions,
        ))
        lastSnapshot = mutation.after
    }

    /// Only newly appended records are visited on the gameplay write path.
    func suffix(after count: Int) -> [(index: Int, record: Record)] {
        history.suffix(after: count)
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.history.sharesStorage(with: rhs.history), lhs.id == rhs.id {
            return true
        }
        return lhs.id == rhs.id && lhs.checkpoint == rhs.checkpoint && lhs.records.elementsEqual(rhs.records)
    }

    mutating func acknowledge(_ ids: Set<String>) {
        guard records.contains(where: { ids.contains($0.id) }) else { return }
        // Rebase only after receipt; old prefixes remain immutable if an archive
        // still references them. Separate domain action IDs survive the rebase.
        var remaining = Self()
        for mutation in self where !ids.contains(mutation.id) {
            remaining.append(mutation)
        }
        self = remaining
    }

    struct Iterator: IteratorProtocol {
        var records: CloudSaveJournalRecords.Iterator
        var snapshot: CloudSaveSnapshot?

        mutating func next() -> CloudSaveMutation? {
            guard let record = records.next(), let snapshot else { return nil }
            let before = record.before?.applying(to: snapshot) ?? snapshot
            let after = record.after.applying(to: before)
            self.snapshot = after
            return CloudSaveMutation(
                id: record.id, changedSliceMask: record.changedSliceMask,
                before: before, after: after, economy: record.economy, receipts: record.receipts, actions: record.actions,
                collectionPositions: record.collectionPositions,
            )
        }
    }

    func makeIterator() -> Iterator {
        Iterator(records: records.makeIterator(), snapshot: checkpoint)
    }

    static let referencesKey = CodingUserInfoKey(rawValue: "Trinket.cloudJournalReferences")
    static let rowsKey = CodingUserInfoKey(rawValue: "Trinket.cloudJournalRows")

    private enum CodingKeys: String, CodingKey { case version, id, count, checkpoint, records }

    init(from decoder: any Decoder) throws {
        // Version-one metadata used complete before/after arrays, including
        // compacted historical records. Preserve exactly what those arrays know.
        let legacyContainer: (any UnkeyedDecodingContainer)?
        do {
            legacyContainer = try decoder.unkeyedContainer()
        } catch DecodingError.typeMismatch(_, _) {
            legacyContainer = nil
        }
        if var legacy = legacyContainer {
            self.init()
            while !legacy.isAtEnd {
                try append(legacy.decode(CloudSaveMutation.self))
            }
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try (1 ... 2).contains(container.decode(Int.self, forKey: .version)) else { throw CloudSaveError.unsupportedSave }
        let id = try container.decode(String.self, forKey: .id)
        let count = try container.decode(Int.self, forKey: .count)
        guard count >= 0 else { throw CloudSaveError.unsupportedSave }
        self.init()
        self.id = id
        if container.contains(.records) {
            checkpoint = try container.decodeIfPresent(CloudSaveSnapshot.self, forKey: .checkpoint)
            lastSnapshot = checkpoint
            var records = try container.nestedUnkeyedContainer(forKey: .records)
            while !records.isAtEnd {
                try appendDecoded(records.decode(Record.self))
            }
            guard history.count == count else { throw CloudSaveError.unsupportedSave }
        } else if count > 0 {
            guard let key = Self.rowsKey, let rows = decoder.userInfo[key] as? [String: [Int: Data]],
                  let journal = rows[id], let checkpointData = journal[-1], count <= journal.count - 1
            else { throw CloudSaveError.unsupportedSave }
            checkpoint = try JSONDecoder().decode(CloudSaveSnapshot.self, from: checkpointData)
            lastSnapshot = checkpoint
            for index in 0 ..< count {
                guard let data = journal[index] else { throw CloudSaveError.unsupportedSave }
                try appendDecoded(JSONDecoder().decode(Record.self, from: data))
            }
        }
        guard (count == 0 && checkpoint == nil) || (count > 0 && checkpoint != nil) else { throw CloudSaveError.unsupportedSave }
    }

    private mutating func appendDecoded(_ record: Record) {
        hasActions = hasActions || record.actions != nil
        history.append(record)
        if let current = lastSnapshot {
            let before = record.before?.applying(to: current) ?? current
            lastSnapshot = record.after.applying(to: before)
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(hasActions ? 2 : 1, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(count, forKey: .count)
        if let key = Self.referencesKey, encoder.userInfo[key] as? Bool == true {
            return
        }
        try container.encodeIfPresent(checkpoint, forKey: .checkpoint)
        var recordsContainer = container.nestedUnkeyedContainer(forKey: .records)
        for record in records {
            try recordsContainer.encode(record)
        }
    }
}
