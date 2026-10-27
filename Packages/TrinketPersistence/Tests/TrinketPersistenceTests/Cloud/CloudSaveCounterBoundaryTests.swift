import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

extension CloudSaveSyncTests {
    @Test func `collection positions must match every collected resource`() throws {
        func receipt(_ positions: [HomesteadResource: UInt64]) -> SaveEconomicReceipt {
            SaveEconomicReceipt(
                kind: .collection(.init(positions: positions, pending: [:], nodeTiers: [:], date: Date(), gold: 0)),
                effects: .committed(materials: [.stone: 1]),
            )
        }
        try receipt([.stone: 0]).validate()
        #expect(throws: CloudSaveError.unsupportedSave) { try receipt([.wood: 0]).validate() }
        #expect(throws: CloudSaveError.unsupportedSave) { try receipt([.stone: 0, .wood: 0]).validate() }
    }

    @Test func `maximum collection retains unpaid credit through receipt replay and stale branch reconciliation`() throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        var base = PlayerSave.testSeed
        base.homestead = PlayerHomesteadState(
            resources: [:], nodeTiers: [:], pendingProduction: [.stone: Double(Int.max)], lastProductionAt: date,
        )
        let receipt = SaveEconomicReceipt(
            kind: .collection(.init(
                positions: [.stone: 0],
                pending: base.homestead.pendingProduction,
                nodeTiers: [:],
                date: date,
                gold: 0,
            )),
            effects: .committed(materials: [.stone: Int.max]),
        )
        try receipt.validate()
        var claims = CloudProductionClaims()
        var collected = base
        for _ in 0 ..< 2 {
            try claims.replay(receipt, onto: &collected)
            #expect(collected.homestead.resources[.stone] == Int.max)
            #expect(collected.homestead.pendingProduction[.stone] == 1)
        }
        try claims.validate()

        // A stale unrelated action must subtract the remote collection from its own credit.
        collected.homestead.pendingProduction = [:]
        let head = CloudSaveHead(
            formatVersion: 2, epoch: "epoch", resetCount: 0, authoritySequence: 0,
            revision: CloudSaveRevision(id: "collected", clock: ["device": 1], snapshot: CloudSaveSnapshot(collected)),
            productionClaims: claims,
        )
        let mutation = CloudSaveMutation(
            id: "stale", changedSliceMask: PlayerSaveSlice.all.rawValue,
            before: CloudSaveSnapshot(base), after: CloudSaveSnapshot(base), receipts: [],
        )
        var replay = CloudReceiptReplay(head: head)
        var merged = collected
        try replay.apply([], mutation: mutation, before: base, after: base, existing: collected, merged: &merged)
        let reloaded = try CloudSaveSnapshot(merged).restored()
        #expect(reloaded.homestead.pendingProduction[.stone] == 1)
        #expect(reloaded.homestead.resources[.stone] == Int.max)
    }

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
