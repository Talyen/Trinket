import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct CloudProductionCapacityTests {
    @Test(arguments: [HomesteadResource.gold, .stone], [0, 4]) @MainActor
    func `replayed collections preserve unpaid credit when a peer filled the balance`(
        resource: HomesteadResource, availableCapacity: Int,
    ) throws {
        let date = Date(timeIntervalSince1970: 2000000000)
        let limit = resource == .gold ? PlayerRosterState.maxGoldBalance : Int.max
        var save = PlayerSave.testSeed
        save.homestead = PlayerHomesteadState(
            resources: resource == .gold ? [:] : [resource: limit - availableCapacity],
            nodeTiers: [:], pendingProduction: [resource: 10], lastProductionAt: date,
        )
        save.roster.gold = resource == .gold ? limit - availableCapacity : 0
        let receipt = SaveEconomicReceipt(
            kind: .collection(.init(
                positions: [resource: 0], pending: [resource: 10], nodeTiers: [:], date: date, gold: 0,
            )),
            effects: .committed(
                gold: resource == .gold ? 10 : 0,
                materials: resource == .gold ? [:] : [resource: 10],
            ),
        )
        try receipt.validate()
        var claims = CloudProductionClaims()
        try claims.replay(receipt, onto: &save)
        let unpaid = 10 - availableCapacity
        #expect(save.homestead.balance(for: resource, gold: save.roster.gold) == limit)
        #expect(save.homestead.pendingProduction[resource] == Double(unpaid))
        #expect(claims.positions[resource] == 10)

        // Retained credit must survive the same wire and graph codecs as a sync result.
        claims = try JSONDecoder().decode(CloudProductionClaims.self, from: JSONEncoder().encode(claims))
        let snapshot = try JSONDecoder().decode(PlayerSaveSnapshot.self, from: JSONEncoder().encode(PlayerSaveSnapshot(save)))
        let context = try PersistenceTestContext()
        save = try context.seedAndReload(snapshot.decodedSave()).currentSave
        #expect(save.homestead.pendingProduction[resource] == Double(unpaid))
        if resource == .gold {
            save.applyGoldDelta(-10, at: date)
        } else {
            save.homestead.resources[resource, default: 0] -= 10
        }
        try claims.replay(receipt, onto: &save)
        #expect(save.homestead.balance(for: resource, gold: save.roster.gold) == limit - 10)
        #expect(save.homestead.pendingProduction[resource] == Double(unpaid))

        var replayed = save
        let nextReceipt = SaveEconomicReceipt(
            kind: .collection(.init(
                positions: [resource: 10], pending: [resource: Double(unpaid)], nodeTiers: [:], date: date, gold: save.roster.gold,
            )),
            effects: .committed(
                gold: resource == .gold ? unpaid : 0,
                materials: resource == .gold ? [:] : [resource: unpaid],
            ),
        )
        try nextReceipt.validate()
        let collected = save.homestead.collectProduction(at: date, gold: &save.roster.gold)
        #expect(collected == [ResourceAmount(resource, unpaid)])
        #expect(save.homestead.balance(for: resource, gold: save.roster.gold) == limit - availableCapacity)
        #expect(save.homestead.pendingProduction[resource] == nil)
        try claims.replay(nextReceipt, onto: &replayed)
        #expect(replayed.homestead == save.homestead)
        #expect(replayed.roster.gold == save.roster.gold)
        try claims.replay(receipt, onto: &replayed)
        #expect(replayed.homestead == save.homestead)
        #expect(replayed.roster.gold == save.roster.gold)
    }
}
