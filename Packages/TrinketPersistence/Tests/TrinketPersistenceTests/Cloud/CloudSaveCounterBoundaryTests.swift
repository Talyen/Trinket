import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

extension CloudSaveSyncTests {
    @Test func `collection refuses payment when its consumption identity cannot be retained`() throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        var save = PlayerSave.testSeed
        save.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [:], pendingProduction: [.wood: 2], lastProductionAt: date,
        )
        let snapshot = CloudSaveSnapshot(save)
        var claims = CloudProductionClaims()
        claims.resources[.wood] = [.init(start: 0, end: .max)]
        let head = CloudSaveHead(
            formatVersion: 2, epoch: "epoch", resetCount: 0, authoritySequence: 0,
            revision: CloudSaveRevision(id: "base", clock: ["device": 1], snapshot: snapshot),
            productionClaims: claims,
        )
        let server = CloudServerSave(head: head, changeToken: Data(), serverTime: date)
        let request = CloudSaveRequest(
            id: "collect", action: .collect, baseEpoch: head.epoch, baseRevisionID: head.revision.id,
            authoritySequence: 0,
            revision: CloudSaveRevision(id: "collect", clock: ["device": 2], snapshot: snapshot), baseSnapshot: snapshot,
        )

        #expect(throws: CloudSaveError.unsupportedSave) {
            try CloudSaveReconciler.resolve(request, against: server)
        }
    }

    @Test(arguments: [false, true])
    @MainActor func `an exhausted revision counter preserves offline progress and outbox across reload`(observedClock: Bool) async throws {
        let context = try PersistenceTestContext()
        let transport = CloudSaveTestTransport()
        var store: PlayerSaveStore? = try cloudStore(context, transport: transport)
        #expect(await store?.cloudSync?.synchronize() == true)
        #expect(store?.persistFixtureBatch(logging: "Offline reward") { $0.roster.gold += 17 } == true)
        var state = try #require(store?.cloudDeviceState)
        if observedClock {
            state.account.base?.revision.clock[state.deviceID] = .max
        } else {
            state.counter = .max
        }
        try store?.commitCloudState(state)
        let local = try #require(store?.currentSave)
        let remote = await transport.account()
        store = nil

        let reloaded = try cloudStore(context, transport: transport)
        #expect(reloaded.cloudDeviceState == state)
        #expect(await reloaded.cloudSync?.synchronize() == false)
        #expect(reloaded.currentSave == local)
        #expect(reloaded.cloudDeviceState == state)
        let after = await transport.account()
        #expect(after.head?.head == remote.head?.head)
        #expect(after.receipts == remote.receipts)
        let persisted = try context.makeReloadedStore()
        #expect(persisted.currentSave == local)
        #expect(persisted.cloudDeviceState == state)
    }

    @Test(arguments: [CloudSaveRequest.Action.reset, .collect, .upgrade(.wheatField, 2)])
    func `exhausted server generations refuse reset and production instead of wrapping`(action: CloudSaveRequest.Action) throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        var save = PlayerSave.testSeed
        save.roster.gold = 100
        save.homestead = PlayerHomesteadState(
            resources: [.wood: 99, .herbs: 99], nodeTiers: [.wheatField: 1, .wishingWell: 1], lastProductionAt: date,
        )
        let snapshot = CloudSaveSnapshot(save)
        let head = CloudSaveHead(
            epoch: "epoch", resetCount: action == .reset ? .max : 0,
            authoritySequence: action == .reset ? 0 : .max,
            revision: CloudSaveRevision(id: "base", clock: ["device": 1], snapshot: snapshot),
        )
        // Exercise the same maximum values accepted from a persisted remote head.
        let decoded = try JSONDecoder().decode(CloudSaveHead.self, from: JSONEncoder().encode(head))
        let server = CloudServerSave(
            head: decoded, changeToken: Data(), serverTime: date.addingTimeInterval(PlayerHomesteadState.secondsPerDay),
        )
        let request = CloudSaveRequest(
            id: "next", action: action, baseEpoch: head.epoch, baseRevisionID: head.revision.id,
            authoritySequence: head.authoritySequence,
            revision: CloudSaveRevision(id: "next", clock: ["device": 2], snapshot: snapshot), baseSnapshot: snapshot,
        )
        #expect(throws: CloudSaveError.unsupportedSave) {
            try CloudSaveReconciler.resolve(request, against: server)
        }
    }
}
