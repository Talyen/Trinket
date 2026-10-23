import Foundation
import SwiftData

/// Independent rows avoid rewriting a growing journal on every gameplay save.
/// Index -1 holds the checkpoint; nonnegative indices hold individual actions.
@Model
final class CloudOutboxRecord {
    var journalID: String = ""
    var index: Int = -1
    var payload: Data = Data()

    init(journalID: String, index: Int, payload: Data) {
        self.journalID = journalID
        self.index = index
        self.payload = payload
    }
}

@MainActor
final class CloudSaveOutbox {
    struct StoredRecord: Codable {
        let journalID: String
        let index: Int
        let payload: Data
    }

    /// Fully encoded before touching SwiftData. Retired payloads are retained
    /// only for this write, so compensation never needs to encode old history.
    struct Update {
        let metadata: Data
        fileprivate let additions: [StoredRecord]
        fileprivate let removals: [StoredRecord]
    }

    private let context: ModelContext
    private var rows: [String: [Int: CloudOutboxRecord]] = [:]

    init(context: ModelContext) throws {
        self.context = context
        for row in try context.fetch(FetchDescriptor<CloudOutboxRecord>()) {
            guard rows[row.journalID]?[row.index] == nil else { throw CloudSaveError.unsupportedSave }
            rows[row.journalID, default: [:]][row.index] = row
        }
    }

    var storedRecords: [StoredRecord] {
        rows.values.flatMap { journal in
            journal.values.map { StoredRecord(journalID: $0.journalID, index: $0.index, payload: $0.payload) }
        }
    }

    func decode(_ data: Data?) throws -> CloudDeviceState {
        guard let data else { return CloudDeviceState() }
        let decoder = JSONDecoder()
        if let key = CloudSaveJournal.rowsKey {
            decoder.userInfo[key] = rows.mapValues { $0.mapValues(\.payload) }
        }
        var state = try decoder.decode(CloudDeviceState.self, from: data)
        guard (1 ... 4).contains(state.formatVersion) else { throw CloudSaveError.unsupportedSave }
        state.formatVersion = max(2, state.formatVersion)
        return state
    }

    func prepare(_ state: CloudDeviceState) throws -> Update {
        var journals: [String: CloudSaveJournal] = [:]
        for account in [state.account] + state.archives.values.map(\.state) {
            for journal in [account.journal, account.pending?.mutations].compactMap(\.self) where !journal.isEmpty {
                if journals[journal.id].map({ $0.count >= journal.count }) != true {
                    journals[journal.id] = journal
                }
            }
        }
        let encoder = JSONEncoder()
        var additions: [StoredRecord] = []
        var removals: [StoredRecord] = []
        for (id, journal) in journals {
            let existingCount = max(0, (rows[id]?.count ?? 0) - 1)
            if rows[id] == nil, let checkpoint = journal.checkpoint {
                try additions.append(StoredRecord(journalID: id, index: -1, payload: encoder.encode(checkpoint)))
            }
            for (index, record) in journal.suffix(after: existingCount) {
                try additions.append(StoredRecord(journalID: id, index: index, payload: encoder.encode(record)))
            }
            if existingCount > journal.count {
                for index in journal.count ..< existingCount {
                    if let row = rows[id]?[index] {
                        removals.append(StoredRecord(journalID: id, index: index, payload: row.payload))
                    }
                }
            }
        }
        for (id, journal) in rows where journals[id] == nil {
            for row in journal.values {
                removals.append(StoredRecord(journalID: id, index: row.index, payload: row.payload))
            }
        }
        if let key = CloudSaveJournal.referencesKey {
            encoder.userInfo[key] = true
        }
        return try Update(metadata: encoder.encode(state), additions: additions, removals: removals)
    }

    /// Apply immediately after preparation on the store's actor, with no
    /// intervening suspension or other outbox update.
    func apply(_ update: Update) {
        for record in update.removals {
            remove(record)
        }
        for record in update.additions {
            insert(record)
        }
    }

    func compensate(_ update: Update) {
        for record in update.additions {
            remove(record)
        }
        for record in update.removals {
            insert(record)
        }
    }

    /// Bootstrap migration also prepares every payload before staging rows.
    func stage(_ state: CloudDeviceState) throws -> Data {
        let update = try prepare(state)
        apply(update)
        return update.metadata
    }

    /// A recovery record owns its row payloads, so it survives loss of the primary
    /// database and never resolves journal references against an older graph.
    func restore(_ records: [StoredRecord]) throws {
        var recovered: [String: [Int: Data]] = [:]
        for record in records {
            guard recovered[record.journalID]?[record.index] == nil else { throw CloudSaveError.unsupportedSave }
            recovered[record.journalID, default: [:]][record.index] = record.payload
        }
        for journal in rows.values {
            for row in journal.values {
                context.delete(row)
            }
        }
        rows.removeAll()
        for record in records {
            insert(record)
        }
    }

    private func insert(_ record: StoredRecord) {
        let row = CloudOutboxRecord(journalID: record.journalID, index: record.index, payload: record.payload)
        context.insert(row)
        rows[record.journalID, default: [:]][record.index] = row
    }

    private func remove(_ record: StoredRecord) {
        if let row = rows[record.journalID]?.removeValue(forKey: record.index) {
            context.delete(row)
        }
        if rows[record.journalID]?.isEmpty == true {
            rows.removeValue(forKey: record.journalID)
        }
    }
}
