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
        guard (1 ... 3).contains(state.formatVersion) else { throw CloudSaveError.unsupportedSave }
        state.formatVersion = max(2, state.formatVersion)
        return state
    }

    /// Stages additions/pruning in the same context as the gameplay candidate.
    /// A failed write compensates through this same method, never rollback().
    func stage(_ state: CloudDeviceState) throws -> Data {
        var journals: [String: CloudSaveJournal] = [:]
        for account in [state.account] + state.archives.values.map(\.state) {
            for journal in [account.journal, account.pending?.mutations].compactMap(\.self) where !journal.isEmpty {
                if journals[journal.id].map({ $0.count >= journal.count }) != true {
                    journals[journal.id] = journal
                }
            }
        }
        let encoder = JSONEncoder()
        for (id, journal) in journals {
            let existingCount = max(0, (rows[id]?.count ?? 0) - 1)
            if rows[id] == nil, let checkpoint = journal.checkpoint {
                try insert(StoredRecord(journalID: id, index: -1, payload: encoder.encode(checkpoint)))
            }
            for (index, record) in journal.suffix(after: existingCount) {
                try insert(StoredRecord(journalID: id, index: index, payload: encoder.encode(record)))
            }
            if existingCount > journal.count {
                for index in journal.count ..< existingCount {
                    if let row = rows[id]?.removeValue(forKey: index) {
                        context.delete(row)
                    }
                }
            }
        }
        for id in Array(rows.keys) where journals[id] == nil {
            for row in rows.removeValue(forKey: id)?.values ?? [Int: CloudOutboxRecord]().values {
                context.delete(row)
            }
        }
        if let key = CloudSaveJournal.referencesKey {
            encoder.userInfo[key] = true
        }
        return try encoder.encode(state)
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
}
