import CloudKit
import CryptoKit
import Foundation

actor CloudKitSaveTransport: CloudSaveTransport {
    private let container: CKContainer
    private let scope: String
    private let environment: String
    private let zoneID = CKRecordZone.ID(zoneName: "TrinketProgressV1")
    private var preparedAccount: String?

    init(containerIdentifier: String) {
        environment = Bundle.main.object(forInfoDictionaryKey: "TrinketCloudEnvironment") as? String ?? "unconfigured"
        scope = "\(containerIdentifier)|\(environment)"
        container = CKContainer(identifier: containerIdentifier)
    }

    func accountID() async throws -> String? {
        guard ["Development", "Production"].contains(environment) else { throw CloudSaveError.unavailable }
        switch try await container.accountStatus() {
        case .available:
            let user = try await container.userRecordID()
            return SHA256.hash(data: Data("\(scope)|\(user.recordName)".utf8)).map { String(format: "%02x", $0) }.joined()
        case .noAccount, .restricted:
            preparedAccount = nil
            return nil
        case .couldNotDetermine, .temporarilyUnavailable:
            throw CloudSaveError.unavailable
        @unknown default:
            throw CloudSaveError.unavailable
        }
    }

    func fetchHead(accountID: String) async throws -> CloudServerSave? {
        try await prepare(accountID)
        guard let record = try await fetch(recordID("head"), accountID: accountID) else { return nil }
        guard let asset = record["payload"] as? CKAsset, let url = asset.fileURL else {
            throw CloudSaveError.unsupportedSave
        }
        let head = try JSONDecoder().decode(CloudSaveHead.self, from: Data(contentsOf: url))
        guard head.formatVersion == 1 else { throw CloudSaveError.unsupportedSave }
        _ = try head.revision.snapshot.restored()
        return try serverSave(record, head: head)
    }

    func refreshTime(accountID: String, head: CloudServerSave) async throws -> CloudServerSave {
        let record = try restoredRecord(head.changeToken)
        record["clockProbe"] = UUID().uuidString
        let saved = try await save([record], accountID: accountID)
        guard let result = saved[record.recordID] else { throw CloudSaveError.unavailable }
        return try serverSave(result, head: head.head)
    }

    func fetchReceipt(accountID: String, requestID: String) async throws -> CloudSaveReceipt? {
        guard let record = try await fetch(recordID("operation-\(requestID)"), accountID: accountID) else { return nil }
        guard let data = record["payload"] as? Data else { throw CloudSaveError.unsupportedSave }
        return try JSONDecoder().decode(CloudSaveReceipt.self, from: data)
    }

    func commit(
        accountID: String,
        replacing: CloudServerSave?,
        head: CloudSaveHead,
        receipt: CloudSaveReceipt,
        backups: [CloudSaveBackup],
    ) async throws -> CloudServerSave {
        let directory = FileManager.default.temporaryDirectory.appending(path: "TrinketCloud-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            do { try FileManager.default.removeItem(at: directory) } catch {}
        }
        let record = try replacing.map { try restoredRecord($0.changeToken) }
            ?? CKRecord(recordType: "TrinketSaveHead", recordID: recordID("head"))
        record["payload"] = try asset(head, at: directory.appending(path: "head.json"))
        record["clockProbe"] = receipt.requestID
        let operation = CKRecord(recordType: "TrinketSaveOperation", recordID: recordID("operation-\(receipt.requestID)"))
        operation["payload"] = try JSONEncoder().encode(receipt)
        var records = [record, operation]
        for backup in backups {
            let archived = CKRecord(recordType: "TrinketSaveBackup", recordID: recordID("backup-\(backup.id)"))
            archived["payload"] = try asset(backup, at: directory.appending(path: "\(backup.id).json"))
            records.append(archived)
        }
        let saved = try await save(records, accountID: accountID)
        guard let result = saved[record.recordID] else { throw CloudSaveError.unavailable }
        return try serverSave(result, head: head)
    }

    private func prepare(_ accountID: String) async throws {
        try await verifyAccount(accountID)
        guard preparedAccount != accountID else { return }
        _ = try await container.privateCloudDatabase.save(CKRecordZone(zoneID: zoneID))
        try await verifyAccount(accountID)
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: "trinket-progress-v1")
        subscription.recordType = "TrinketSaveHead"
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        _ = try await container.privateCloudDatabase.save(subscription)
        try await verifyAccount(accountID)
        preparedAccount = accountID
    }

    private func verifyAccount(_ expected: String) async throws {
        try Task.checkCancellation()
        guard try await accountID() == expected else { throw CloudSaveError.accountChanged }
    }

    private func fetch(_ id: CKRecord.ID, accountID: String) async throws -> CKRecord? {
        try await verifyAccount(accountID)
        do {
            let record = try await container.privateCloudDatabase.record(for: id)
            try await verifyAccount(accountID)
            return record
        } catch let error as CKError where error.code == .unknownItem {
            try await verifyAccount(accountID)
            return nil
        }
    }

    private func save(_ records: [CKRecord], accountID: String) async throws -> [CKRecord.ID: CKRecord] {
        try await verifyAccount(accountID)
        do {
            let result = try await container.privateCloudDatabase.modifyRecords(
                saving: records, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: true,
            )
            try await verifyAccount(accountID)
            let errors = result.saveResults.values.compactMap { result -> (any Error)? in
                if case let .failure(error) = result {
                    return error
                }
                return nil
            }
            if errors.contains(where: Self.isConflict) {
                throw CloudSaveError.conflict
            }
            if let error = errors.first {
                throw error
            }
            return try result.saveResults.mapValues { try $0.get() }
        } catch {
            if Self.isConflict(error) {
                throw CloudSaveError.conflict
            }
            throw error
        }
    }

    /// Pure CKError→conflict mapping shared by save paths. Internal for
    /// isolated coverage: conflict retries the same request ID, anything
    /// else surfaces (see `PlayerSaveCloudSync.synchronizeUntilCurrent`).
    static func isConflict(_ error: any Error) -> Bool {
        guard let error = error as? CKError else { return (error as? CloudSaveError) == .conflict }
        if error.code == .serverRecordChanged {
            return true
        }
        return error.partialErrorsByItemID?.values.contains(where: isConflict) ?? false
    }

    private func recordID(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    private func asset(_ value: some Encodable, at url: URL) throws -> CKAsset {
        try JSONEncoder().encode(value).write(to: url, options: .atomic)
        return CKAsset(fileURL: url)
    }

    private func restoredRecord(_ data: Data) throws -> CKRecord {
        let decoder = try NSKeyedUnarchiver(forReadingFrom: data)
        decoder.requiresSecureCoding = true
        defer { decoder.finishDecoding() }
        guard let record = CKRecord(coder: decoder) else { throw CloudSaveError.unsupportedSave }
        return record
    }

    private func serverSave(_ record: CKRecord, head: CloudSaveHead) throws -> CloudServerSave {
        guard let date = record.modificationDate else { throw CloudSaveError.unavailable }
        let encoder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: encoder)
        encoder.finishEncoding()
        return CloudServerSave(head: head, changeToken: encoder.encodedData, serverTime: date)
    }
}
