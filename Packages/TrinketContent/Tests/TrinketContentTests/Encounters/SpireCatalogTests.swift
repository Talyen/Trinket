import Testing
import TrinketContent
import TrinketCore

@Suite("SpireCatalog")
struct SpireCatalogTests {
    @Test func `damage spires are authored`() throws {
        try #expect(!GameContent.spires.isEmpty)
        let ids = GameContent.spires.map(\.id)
        try #expect(Set(ids).count == ids.count)
        for spire in GameContent.spires {
            try #expect(spire.keyword.category == .damageType)
            try #expect(!spire.title.isEmpty)
            try #expect(spire.title != spire.keyword.rawValue)
            try #expect(GameContent.spireFloors(for: spire.id).count == spire.floorCount)
        }
    }

    @Test func `floors resolve existing enemies`() throws {
        for spire in GameContent.spires {
            for floor in GameContent.spireFloors(for: spire.id) {
                #expect(GameContent.spireFloor(spireID: spire.id, floor: floor.floor) == floor)
                let enemy = try #require(GameContent.enemy(matching: floor.enemyID), "Missing enemy \(floor.enemyID)")
                let isBoss = enemy.isBoss
                try #expect(isBoss == floor.floor.isMultiple(of: 10), "Floor \(floor.floor) boss mismatch")
            }
        }
    }

    @Test func `floor lookup rejects invalid floor numbers`() throws {
        let spire = try #require(GameContent.spire(id: .ironVein))
        #expect(GameContent.spireFloor(spireID: spire.id, floor: 0) == nil)
        #expect(GameContent.spireFloor(spireID: spire.id, floor: spire.floorCount + 1) == nil)
    }

    @Test func `every floor rolls one stable modifier from its keyword pool`() throws {
        for spire in GameContent.spires {
            let pool = NodeModifierCatalog.keywordModifiers(for: spire.keyword, nodeType: .battle)
            #expect(pool.count == 3)
            #expect(Set(pool.map(\.id)).count == 3)
            let bossPool = NodeModifierCatalog.keywordModifiers(for: spire.keyword, nodeType: .boss)
            #expect(bossPool == pool.filter { $0.effect != .reward(.keyword(spire.keyword)) })
            #expect(pool.contains { $0.effect == .damageDealt(keyword: spire.keyword, amount: 1) })
            #expect(pool.contains { $0.effect == .damageTakenReduction(keyword: spire.keyword, percent: 50) })
            #expect(pool.contains { $0.effect == .reward(.keyword(spire.keyword)) })

            for floor in GameContent.spireFloors(for: spire.id) {
                let first = try #require(GameContent.spireModifier(for: floor, worldSeed: 42))
                #expect((floor.floor.isMultiple(of: 10) ? bossPool : pool).contains(first))
                #expect(GameContent.spireModifier(for: floor, worldSeed: 42) == first)
            }
        }
    }
}
