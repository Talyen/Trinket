import Foundation
import Testing
import TrinketContent
import TrinketCore
@testable import TrinketPersistence

struct HomesteadStateTests {
    @Test func `extreme saved production collects safely and preserves overflow`() throws {
        let date = Date(timeIntervalSince1970: 1000)
        var homestead = PlayerHomesteadState(
            resources: [:],
            nodeTiers: [:],
            pendingProduction: [.food: Double(Int.max) * 2],
            lastProductionAt: date,
        )
        homestead = try JSONDecoder().decode(PlayerHomesteadState.self, from: JSONEncoder().encode(homestead))
        homestead = PlayerSaveSanitizer.sanitizeHomestead(homestead)
        var roster = PlayerRosterState.freshStart

        let preview = homestead.pendingProductionAmounts(at: date, gold: roster.gold)
        #expect(preview == [ResourceAmount(.food, Int.max)])
        #expect(homestead.collectProduction(at: date, gold: &roster.gold) == preview)
        #expect(homestead.resources[.food] == Int.max)
        #expect(homestead.pendingProduction[.food] == Double(Int.max))
        #expect(homestead.collectProduction(at: date, gold: &roster.gold).isEmpty)
    }

    @Test func `material grants saturate and report only the applied gain`() {
        let date = Date(timeIntervalSince1970: 1000)
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: date,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart,
            homestead: PlayerHomesteadState(
                resources: [.wood: Int.max - 2, .stone: Int.max],
                nodeTiers: [:],
                lastProductionAt: date,
            ),
        )

        let granted = save.grantMaterials([
            ResourceAmount(.wood, Int.max),
            ResourceAmount(.wood, 5),
            ResourceAmount(.stone, 1),
        ], at: date)

        #expect(granted == [ResourceAmount(.wood, 2)])
        #expect(save.homestead.resources[.wood] == Int.max)
        #expect(save.homestead.resources[.stone] == Int.max)
    }

    @Test func `material grant settles production before applying reward`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: start,
            journey: .initial,
            roster: .freshStart,
            inventory: .freshStart,
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wheatField: 1],
                lastProductionAt: start,
            ),
        )

        let granted = save.grantMaterials(
            [ResourceAmount(.food, 1000)],
            at: start.addingTimeInterval(PlayerHomesteadState.secondsPerDay),
        )

        try #expect(granted == [ResourceAmount(.food, 1000)])
        try #expect(save.homestead.resources[.food] == 1000)
        try #expect(save.homestead.pendingProduction[.food] == 1)
    }

    @Test func `gold grant settles production and returns actual amount`() throws {
        let start = Date(timeIntervalSince1970: 0)
        var roster = PlayerRosterState.freshStart
        roster.gold = 995
        var save = PlayerSave(
            schemaVersion: PlayerSave.currentSchemaVersion,
            modifiedAt: start,
            journey: .initial,
            roster: roster,
            inventory: .freshStart,
            homestead: PlayerHomesteadState(
                resources: [:],
                nodeTiers: [.wishingWell: 1],
                lastProductionAt: start,
            ),
        )

        let granted = save.grantGold(10, at: start.addingTimeInterval(PlayerHomesteadState.secondsPerDay))

        try #expect(granted == 3)
        try #expect(save.roster.gold == PlayerRosterState.maxGoldBalance - 1)
        try #expect(save.homestead.pendingProduction[.gold] == 1)
    }
}
