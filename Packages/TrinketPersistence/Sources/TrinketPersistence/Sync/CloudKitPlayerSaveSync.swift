import CloudKit
import Foundation
import os

public struct CloudKitPlayerSaveSync: PlayerSaveSyncing {
    public static let recordType = "PlayerSave"
    public static let recordName = "primary"
    public static let containerIdentifier = "iCloud.com.ryanmcintire.Trinket"

    private let container: CKContainer
    private let logger = Logger(
        subsystem: PlayerSaveDefaults.loggingSubsystem,
        category: "CloudSync"
    )

    public init(container: CKContainer = CKContainer(identifier: CloudKitPlayerSaveSync.containerIdentifier)) {
        self.container = container
    }

    public func accountStatus() async -> PlayerSaveAccountStatus {
        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                return .available
            case .noAccount:
                return .unavailable("Sign in to iCloud to sync progress across devices.")
            case .restricted:
                return .unavailable("iCloud is restricted on this device.")
            case .couldNotDetermine:
                return .unavailable("Couldn't determine iCloud account status.")
            case .temporarilyUnavailable:
                return .unavailable("iCloud is temporarily unavailable.")
            @unknown default:
                return .unavailable("iCloud is unavailable.")
            }
        } catch {
            logger.error("Account status failed: \(error.localizedDescription, privacy: .public)")
            return .unavailable("Couldn't check iCloud account status.")
        }
    }

    public func fetchRemoteSave() async throws -> RemotePlayerSave? {
        let recordID = CKRecord.ID(recordName: Self.recordName)
        let database = container.privateCloudDatabase

        do {
            let record = try await database.record(for: recordID)
            return try remoteSave(from: record)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    public func upload(_ save: PlayerSave, replacingRecordChangeTag: String?) async throws -> String? {
        let database = container.privateCloudDatabase
        let recordID = CKRecord.ID(recordName: Self.recordName)
        let record: CKRecord
        do {
            let existing = try await database.record(for: recordID)
            if let expectedTag = replacingRecordChangeTag,
               let actualTag = existing.recordChangeTag,
               actualTag != expectedTag
            {
                throw PlayerSaveSyncError.recordConflict(try remoteSave(from: existing))
            }
            record = existing
        } catch let error as CKError where error.code == .unknownItem {
            record = CKRecord(recordType: Self.recordType, recordID: recordID)
        }

        let encoder = PlayerSaveCoding.makeEncoder()
        let data = try encoder.encode(save)
        let temporaryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlayerSave-\(UUID().uuidString).json")
        try data.write(to: temporaryURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        record["saveData"] = CKAsset(fileURL: temporaryURL)
        record["modifiedAt"] = save.modifiedAt
        record["schemaVersion"] = Int64(save.schemaVersion)

        do {
            let saved = try await database.save(record)
            return saved.recordChangeTag
        } catch let error as CKError where error.code == .serverRecordChanged {
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                throw PlayerSaveSyncError.recordConflict(try remoteSave(from: serverRecord))
            }
            throw error
        }
    }

    public func subscribeToChanges() async throws {
        let database = container.privateCloudDatabase
        let subscriptionID = "player-save-changes"
        let subscription = CKDatabaseSubscription(subscriptionID: subscriptionID)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        do {
            _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
        } catch let error as CKError where error.code == .serverRejectedRequest {
            logger.info("CloudKit subscription already exists.")
        } catch {
            throw error
        }
    }

    private func remoteSave(from record: CKRecord) throws -> RemotePlayerSave {
        guard let asset = record["saveData"] as? CKAsset,
              let fileURL = asset.fileURL
        else {
            throw CKError(.internalError)
        }

        let data = try Data(contentsOf: fileURL)
        let decoder = PlayerSaveCoding.makeDecoder()
        let save = try decoder.decode(PlayerSave.self, from: data)
        let modifiedAt = (record["modifiedAt"] as? Date) ?? save.modifiedAt

        return RemotePlayerSave(
            save: save,
            modifiedAt: modifiedAt,
            recordChangeTag: record.recordChangeTag
        )
    }
}
