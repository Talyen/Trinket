import Darwin
import Foundation
import SwiftData
import Testing
import TrinketContent
import TrinketPersistenceTestSupport
@testable import TrinketAppState
@testable import TrinketBattleFeature
@testable import TrinketPersistence

/// Disposable disk server survives the owned worker's hard exit. Production sync
/// owns outbox/request handling; this transport only supplies atomic remote I/O.
private actor DiskCloudTransport: CloudSaveTransport {
    struct Remote: Codable {
        var head: CloudSaveHead?
        var receipts: [String: CloudSaveReceipt] = [:]
        var backups: [CloudSaveBackup] = []
        var token = 0
    }

    let directory: URL
    var interrupts = false

    init(directory: URL) {
        self.directory = directory
    }

    func interruptNextAcknowledgement() {
        interrupts = true
    }

    func accountID() -> String? {
        "process-account"
    }

    func remote() throws -> Remote {
        let url = directory.appendingPathComponent("remote.json")
        guard FileManager.default.fileExists(atPath: url.path) else { return Remote() }
        return try JSONDecoder().decode(Remote.self, from: Data(contentsOf: url))
    }

    private func server(_ remote: Remote) -> CloudServerSave? {
        remote.head.map {
            CloudServerSave(
                head: $0,
                changeToken: Data(String(remote.token).utf8),
                serverTime: Date(timeIntervalSince1970: 2000000000),
            )
        }
    }

    func fetchHead(accountID _: String) throws -> CloudServerSave? {
        try server(remote())
    }

    func refreshTime(accountID _: String, head: CloudServerSave) throws -> CloudServerSave {
        guard let current = try server(remote()), current.changeToken == head.changeToken else {
            throw CloudSaveError.conflict
        }
        return current
    }

    func fetchReceipt(accountID _: String, requestID: String) throws -> CloudSaveReceipt? {
        try remote().receipts[requestID]
    }

    func commit(
        accountID _: String, replacing: CloudServerSave?, head: CloudSaveHead,
        receipt: CloudSaveReceipt, backups: [CloudSaveBackup],
    ) throws -> CloudServerSave {
        var value = try remote()
        guard server(value)?.changeToken == replacing?.changeToken,
              value.receipts[receipt.requestID] == nil else { throw CloudSaveError.conflict }
        value.head = head
        value.receipts[receipt.requestID] = receipt
        value.backups += backups
        value.token += 1
        try JSONEncoder().encode(value).write(to: directory.appendingPathComponent("remote.json"), options: .atomic)
        if interrupts {
            try Data("{\"boundary\":\"remote-committed-before-acknowledgement\"}".utf8).write(
                to: directory.appendingPathComponent("interrupted.json"), options: .atomic,
            )
            _exit(86)
        }
        return try #require(server(value))
    }
}

@MainActor
enum CloudProcessRecovery {
    static func run(_ request: PlaythroughWorkerRequest, output: URL) async throws {
        let recovering = request.operation == "cloud-recover"
        if recovering {
            let source = try URL(fileURLWithPath: #require(request.source))
            try FileManager.default.copyItem(at: source.appendingPathComponent("store"), to: output.appendingPathComponent("store"))
            try FileManager.default.copyItem(
                at: source.appendingPathComponent("remote.json"),
                to: output.appendingPathComponent("remote.json"),
            )
        }
        let storeDirectory = output.appendingPathComponent("store")
        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        let schema = PlayerSaveGraph.schema
        let configuration = ModelConfiguration(
            schema: schema,
            url: storeDirectory.appendingPathComponent("save.store"),
            cloudKitDatabase: .none,
        )
        let container = try ModelContainer(for: schema, migrationPlan: PlayerSaveMigrationPlan.self, configurations: configuration)
        let transport = DiskCloudTransport(directory: output)
        let store = try PlayerSaveStore(
            openResult: .init(container: container, usedInMemoryFallback: false),
            cloudSyncEnabled: true, cloudTransport: transport, recoveryConfiguration: configuration,
        )
        if recovering {
            #expect(store.roster.gold == 7)
            let pendingID = try #require(store.cloudDeviceState.account.pending?.id)
            #expect(try await transport.remote().receipts[pendingID] != nil)
            let acceptedReceipts = try await transport.remote().receipts.count
            // Later offline earnings must survive acknowledgement of the frozen prefix.
            #expect(store.persistBatch(logging: "Later offline earnings") { $0.roster.gold += 9 })
            #expect(await store.cloudSync?.synchronize() == true)
            #expect(store.roster.gold == 16)
            #expect(try await transport.remote().head?.revision.snapshot.roster.gold == 16)
            let finalReceiptCount = try await transport.remote().receipts.count
            #expect(finalReceiptCount == acceptedReceipts + 1)
            #expect(await store.cloudSync?.synchronize() == true)
            #expect(try await transport.remote().receipts.count == finalReceiptCount)
            #expect(store.cloudDeviceState.account.pending == nil)
            #expect(store.cloudDeviceState.account.journal?.isEmpty != false)
            try JSONEncoder().encode(CloudSaveSnapshot(store.currentSave)).write(
                to: output.appendingPathComponent("final-save.json"), options: .atomic,
            )
            var summary = PlaythroughSummary()
            summary.termination = "cloudProcessRecovered"
            try JSONEncoder().encode(summary).write(to: output.appendingPathComponent("summary.json"), options: .atomic)
        } else {
            #expect(await store.cloudSync?.synchronize() == true)
            #expect(store.persistBatch(logging: "Earned before interrupted response") { $0.roster.gold += 7 })
            await transport.interruptNextAcknowledgement()
            _ = await store.cloudSync?.synchronize()
            Issue.record("Owned cloud interruption checkpoint was not reached")
        }
    }
}

@Suite(.serialized)
@MainActor
struct CloudPresentationBoundaryTests {
    @Test func `own acknowledgement retains reward exit while remote progress invalidates stale presentation`() async throws {
        let context = try AppTestContext()
        let transport = DiskCloudTransport(directory: context.directoryURL)
        let first = try makeStore(directory: context.directoryURL.appendingPathComponent("a"), transport: transport)
        let second = try makeStore(directory: context.directoryURL.appendingPathComponent("b"), transport: transport)
        let app = try context.makeAppState(playerSave: first)
        #expect(await first.cloudSync?.synchronize() == true)
        #expect(await second.cloudSync?.synchronize() == true)
        // The second device's attachment advances the remote revision. Adopt it
        // before opening the battle so its reward upload is an own acknowledgement.
        #expect(await first.cloudSync?.synchronize() == true)
        let stage = try #require(GameContent.chapters[0].stages.first)
        #expect(app.play.journey.startBattle(for: stage) == nil)
        let battle = try #require(context.lastBattle)
        let configuration = try #require(battle.activeBattle)
        battle.presentLaunchVictory()
        let summary = try #require(battle.spectacle.outcomePresentation.victorySummaryIfAvailable)
        #expect(battle.claimVictory(configurationID: configuration.id, summary: summary, defersPresentationExit: true))
        let gold = first.roster.gold
        #expect(await first.cloudSync?.synchronize() == true)
        #expect(battle.activeBattle?.id == configuration.id)
        #expect(first.journey.hasClaimedRewards(for: stage))
        #expect(second.persistBatch(logging: "Remote earnings") { $0.roster.gold += 9 })
        #expect(await second.cloudSync?.synchronize() == true)
        #expect(await first.cloudSync?.synchronize() == true)
        #expect(battle.activeBattle == nil)
        #expect(first.roster.gold == gold + 9)
        #expect(first.journey.hasClaimedRewards(for: stage))
        let merged = first.currentSave
        battle.finishVictoryPresentation(configurationID: configuration.id)
        #expect(first.currentSave == merged)
        let reopened = try makeStore(directory: context.directoryURL.appendingPathComponent("a"), transport: transport)
        #expect(reopened.roster.gold == gold + 9)
        #expect(reopened.journey.hasClaimedRewards(for: stage))
    }

    private func makeStore(directory: URL, transport: DiskCloudTransport) throws -> PlayerSaveStore {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let schema = PlayerSaveGraph.schema
        let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("save.store"), cloudKitDatabase: .none)
        let container = try ModelContainer(for: schema, migrationPlan: PlayerSaveMigrationPlan.self, configurations: configuration)
        return try PlayerSaveStore(
            openResult: .init(container: container, usedInMemoryFallback: false),
            cloudSyncEnabled: true, cloudTransport: transport, recoveryConfiguration: configuration,
        )
    }
}
