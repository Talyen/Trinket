import Foundation
import TrinketCore

enum CloudSaveError: Error, Equatable {
    case unavailable
    case accountChanged
    case conflict
    case unsupportedSave
    case missingHead
}

struct CloudSaveRevision: Codable, Equatable, Sendable {
    var id: String
    var clock: [String: UInt64]
    var snapshot: CloudSaveSnapshot

    func includes(_ other: [String: UInt64]) -> Bool {
        other.allSatisfy { clock[$0.key, default: 0] >= $0.value }
    }
}

struct CloudSaveHead: Codable, Equatable, Sendable {
    var formatVersion = 1
    var epoch: String
    var resetCount: UInt64
    var authoritySequence: UInt64
    var productionClockEstablished = false
    var revision: CloudSaveRevision
    var productionClaims: CloudProductionClaims?
    var retiredItemIDs: Set<String>?
}

struct CloudSaveRequest: Codable, Equatable, Sendable {
    enum Action: Codable, Equatable, Sendable {
        case upload
        case reset
        case collect
        case upgrade(HomesteadNodeID, Int)
    }

    let id: String
    let action: Action
    let baseEpoch: String?
    let baseRevisionID: String?
    let authoritySequence: UInt64
    let revision: CloudSaveRevision
    let baseSnapshot: CloudSaveSnapshot?
    let mutations: CloudSaveJournal?

    init(
        id: String, action: Action, baseEpoch: String?, baseRevisionID: String?,
        authoritySequence: UInt64, revision: CloudSaveRevision, baseSnapshot: CloudSaveSnapshot? = nil,
        mutations: CloudSaveJournal? = nil,
    ) {
        self.id = id
        self.action = action
        self.baseEpoch = baseEpoch
        self.baseRevisionID = baseRevisionID
        self.authoritySequence = authoritySequence
        self.revision = revision
        self.baseSnapshot = baseSnapshot
        self.mutations = mutations
    }
}

struct CloudSaveMutation: Codable, Equatable, Sendable {
    let id: String
    let changedSliceMask: UInt16
    let before: CloudSaveSnapshot
    let after: CloudSaveSnapshot
    let economy: CloudEconomicAction?
    let receipts: [SaveEconomicReceipt]?
    let collectionPositions: [HomesteadResource: UInt64]?

    init(
        id: String, changedSliceMask: UInt16,
        before: CloudSaveSnapshot, after: CloudSaveSnapshot,
        economy: CloudEconomicAction? = nil,
        receipts: [SaveEconomicReceipt]? = nil,
        collectionPositions: [HomesteadResource: UInt64]? = nil,
    ) {
        self.id = id
        self.changedSliceMask = changedSliceMask
        self.before = before
        self.after = after
        self.economy = economy
        self.receipts = receipts
        self.collectionPositions = collectionPositions
    }
}

struct CloudSaveReceipt: Codable, Equatable, Sendable {
    enum Outcome: Codable, Equatable, Sendable {
        case synchronized
        case collected([HomesteadResource: Int])
        case upgraded
        case insufficientResources
        case notAvailable
        case progressChanged
    }

    let requestID: String
    let epoch: String
    let authoritySequence: UInt64
    let outcome: Outcome
    var acceptedLocalSnapshot = false
}

struct CloudSaveBackup: Codable, Equatable, Sendable {
    let id: String
    let epoch: String?
    let snapshot: CloudSaveSnapshot
}

struct CloudAccountState: Codable, Equatable, Sendable {
    var base: CloudSaveHead?
    var pending: CloudSaveRequest?
    var resetRequested = false
    var journal: CloudSaveJournal?
    var collectionPositions: [HomesteadResource: UInt64]?
}

struct CloudAccountArchive: Codable, Equatable, Sendable {
    let snapshot: CloudSaveSnapshot
    let state: CloudAccountState
}

struct CloudDeviceState: Codable, Equatable, Sendable {
    var formatVersion = 2
    var deviceID = UUID().uuidString
    var counter: UInt64 = 0
    var activeAccountID: String?
    var hasLinkedAccount = false
    var account = CloudAccountState()
    var archives: [String: CloudAccountArchive] = [:]
    var guestBackup: CloudSaveSnapshot?

    /// Maximum retained per-account archives. Evicted oldest-first on insert
    /// via `archiving(_:for:)`.
    static let maxArchives = 5

    mutating func archiving(_ archive: CloudAccountArchive, for accountID: String) {
        archives[accountID] = archive
        guard archives.count > Self.maxArchives else { return }
        // Evict an arbitrary oldest key; archives carry no timestamps, so
        // bound growth without claiming recency.
        for key in archives.keys where key != accountID {
            archives.removeValue(forKey: key)
            if archives.count <= Self.maxArchives {
                break
            }
        }
    }

    static func decode(_ data: Data?) throws -> Self {
        guard let data else { return Self() }
        var value = try JSONDecoder().decode(Self.self, from: data)
        guard (1 ... 3).contains(value.formatVersion) else { throw CloudSaveError.unsupportedSave }
        value.formatVersion = max(2, value.formatVersion)
        return value
    }
}

struct CloudServerSave: Sendable {
    let head: CloudSaveHead
    let changeToken: Data
    let serverTime: Date
}

protocol CloudSaveTransport: Sendable {
    func accountID() async throws -> String?
    func fetchHead(accountID: String) async throws -> CloudServerSave?
    func refreshTime(accountID: String, head: CloudServerSave) async throws -> CloudServerSave
    func fetchReceipt(accountID: String, requestID: String) async throws -> CloudSaveReceipt?
    func commit(
        accountID: String,
        replacing: CloudServerSave?,
        head: CloudSaveHead,
        receipt: CloudSaveReceipt,
        backups: [CloudSaveBackup],
    ) async throws -> CloudServerSave
}
