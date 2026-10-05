import Foundation

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
        let collectionPositions: [HomesteadResource: UInt64]?
    }

    private(set) var id: String
    private(set) var checkpoint: CloudSaveSnapshot?
    private(set) var lastSnapshot: CloudSaveSnapshot?
    private var tail: Node?

    private final class Node: Sendable {
        let records: [Record]
        let previous: Node?
        let count: Int

        init(_ record: Record, previous: Node?) {
            count = (previous?.count ?? 0) + 1
            // Bounded blocks keep append copies small and avoid one recursive
            // ARC release frame per offline action when a journal is retired.
            if let previous, previous.records.count < 64 {
                records = previous.records + [record]
                self.previous = previous.previous
            } else {
                records = [record]
                self.previous = previous
            }
        }
    }

    init(_ mutations: [CloudSaveMutation] = []) {
        id = UUID().uuidString
        for mutation in mutations {
            append(mutation)
        }
    }

    var count: Int {
        tail?.count ?? 0
    }

    var isEmpty: Bool {
        tail == nil
    }

    var records: [Record] {
        suffix(after: 0).map(\.record)
    }

    var first: CloudSaveMutation? {
        var iterator = makeIterator()
        return iterator.next()
    }

    mutating func append(_ mutation: CloudSaveMutation) {
        let previous = lastSnapshot ?? mutation.before
        if checkpoint == nil {
            checkpoint = mutation.before
        }
        let gap = CloudSaveSnapshotDelta(from: previous, to: mutation.before)
        tail = Node(Record(
            id: mutation.id, changedSliceMask: mutation.changedSliceMask,
            before: gap.changes.isEmpty ? nil : gap,
            after: CloudSaveSnapshotDelta(from: mutation.before, to: mutation.after),
            economy: mutation.economy,
            receipts: mutation.receipts,
            collectionPositions: mutation.collectionPositions,
        ), previous: tail)
        lastSnapshot = mutation.after
    }

    /// Only newly appended records are visited on the gameplay write path.
    func suffix(after count: Int) -> [(index: Int, record: Record)] {
        var suffix: [(index: Int, record: Record)] = []
        var node = tail
        while let current = node, current.count > count {
            let start = current.count - current.records.count
            for (offset, record) in current.records.enumerated().reversed() where start + offset >= count {
                suffix.append((start + offset, record))
            }
            node = current.previous
        }
        return Array(suffix.reversed())
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        if lhs.tail === rhs.tail, lhs.id == rhs.id {
            return true
        }
        return lhs.id == rhs.id && lhs.checkpoint == rhs.checkpoint && lhs.records == rhs.records
    }

    mutating func acknowledge(_ ids: Set<String>) {
        guard records.contains(where: { ids.contains($0.id) }) else { return }
        // Rebase only after receipt; old prefixes remain immutable if an archive
        // still references them. Separate domain action IDs survive the rebase.
        self = Self(filter { !ids.contains($0.id) })
    }

    struct Iterator: IteratorProtocol {
        var records: IndexingIterator<[Record]>
        var snapshot: CloudSaveSnapshot?

        mutating func next() -> CloudSaveMutation? {
            guard let record = records.next(), let snapshot else { return nil }
            let before = record.before?.applying(to: snapshot) ?? snapshot
            let after = record.after.applying(to: before)
            self.snapshot = after
            return CloudSaveMutation(
                id: record.id, changedSliceMask: record.changedSliceMask,
                before: before, after: after, economy: record.economy, receipts: record.receipts,
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
            var mutations: [CloudSaveMutation] = []
            while !legacy.isAtEnd {
                try mutations.append(legacy.decode(CloudSaveMutation.self))
            }
            self.init(mutations)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        guard try container.decode(Int.self, forKey: .version) == 1 else { throw CloudSaveError.unsupportedSave }
        let id = try container.decode(String.self, forKey: .id)
        let count = try container.decode(Int.self, forKey: .count)
        guard count >= 0 else { throw CloudSaveError.unsupportedSave }
        let checkpoint: CloudSaveSnapshot?
        let records: [Record]
        if container.contains(.records) {
            checkpoint = try container.decodeIfPresent(CloudSaveSnapshot.self, forKey: .checkpoint)
            records = try container.decode([Record].self, forKey: .records)
            guard records.count == count else { throw CloudSaveError.unsupportedSave }
        } else if count > 0 {
            guard let key = Self.rowsKey, let rows = decoder.userInfo[key] as? [String: [Int: Data]],
                  let journal = rows[id], let checkpointData = journal[-1], count <= journal.count - 1
            else { throw CloudSaveError.unsupportedSave }
            checkpoint = try JSONDecoder().decode(CloudSaveSnapshot.self, from: checkpointData)
            var loaded: [Record] = []
            for index in 0 ..< count {
                guard let data = journal[index] else { throw CloudSaveError.unsupportedSave }
                try loaded.append(JSONDecoder().decode(Record.self, from: data))
            }
            records = loaded
        } else {
            checkpoint = nil
            records = []
        }
        guard (count == 0 && checkpoint == nil) || (count > 0 && checkpoint != nil) else { throw CloudSaveError.unsupportedSave }
        self.init(id: id, checkpoint: checkpoint, records: records)
    }

    private init(id: String, checkpoint: CloudSaveSnapshot?, records: [Record]) {
        self.id = id
        self.checkpoint = checkpoint
        var snapshot = checkpoint
        for record in records {
            tail = Node(record, previous: tail)
            if let current = snapshot {
                let before = record.before?.applying(to: current) ?? current
                snapshot = record.after.applying(to: before)
            }
        }
        lastSnapshot = snapshot
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(1, forKey: .version)
        try container.encode(id, forKey: .id)
        try container.encode(count, forKey: .count)
        if let key = Self.referencesKey, encoder.userInfo[key] as? Bool == true {
            return
        }
        try container.encodeIfPresent(checkpoint, forKey: .checkpoint)
        try container.encode(records, forKey: .records)
    }
}
