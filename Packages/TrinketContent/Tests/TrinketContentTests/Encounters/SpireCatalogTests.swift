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
                try #expect(GameContent.enemy(matching: floor.enemyID) != nil, "Missing enemy \(floor.enemyID)")
                let isBoss = GameContent.enemy(matching: floor.enemyID)?.isBoss == true
                try #expect(isBoss == floor.floor.isMultiple(of: 10), "Floor \(floor.floor) boss mismatch")
            }
            let finalFloor = try #require(GameContent.spireFloor(spireID: spire.id, floor: spire.floorCount))
            try #expect(GameContent.enemy(matching: finalFloor.enemyID)?.isBoss == true)
        }
    }

    @Test func `attunement requires matching ability keywords`() throws {
        let ironVein = try #require(GameContent.spire(id: .ironVein))
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let phoenix = try #require(GameContent.companions.first { $0.id == "phoenix" })

        try #expect(SpireAttunement.matches(rogue, spire: ironVein))
        try #expect(SpireAttunement.matches(bear, spire: ironVein))
        try #expect(!SpireAttunement.matches(phoenix, spire: ironVein))
        try #expect(
            SpireAttunement.canEnter(ironVein, heroes: [rogue], companions: [bear, phoenix]),
        )
        try #expect(
            !SpireAttunement.canEnter(ironVein, heroes: [rogue], companions: [phoenix]),
        )
        try #expect(SpireAttunement.evaluate(hero: rogue, companion: bear, spire: ironVein) == .ready)
        try #expect(
            SpireAttunement.evaluate(hero: rogue, companion: phoenix, spire: ironVein)
                == .missingCompanionAffinity,
        )
    }

    @Test func `every spire has attunable hero and companion`() throws {
        for spire in GameContent.spires {
            let heroes = GameContent.heroes.filter { SpireAttunement.matches($0, spire: spire) }
            let companions = GameContent.companions.filter {
                SpireAttunement.matches($0, spire: spire)
            }
            try #expect(!heroes.isEmpty, "\(spire.title) needs a Hero with \(spire.keyword.rawValue)")
            try #expect(!companions.isEmpty, "\(spire.title) needs a Companion with \(spire.keyword.rawValue)")
            try #expect(
                SpireAttunement.canEnter(
                    spire,
                    heroes: GameContent.heroes,
                    companions: GameContent.companions,
                ),
                "\(spire.title) needs roster unlock from catalog Heroes and Companions",
            )
            let ready = heroes.contains { hero in
                companions.contains { companion in
                    SpireAttunement.evaluate(hero: hero, companion: companion, spire: spire) == .ready
                }
            }
            try #expect(ready, "\(spire.title) needs at least one ready Hero+Companion pair")
        }
    }

    @Test func `spire floor lookup returns indexed floor and handles out of bounds`() throws {
        for spire in GameContent.spires {
            for floorIndex in 1 ... spire.floorCount {
                let floor = try #require(GameContent.spireFloor(spireID: spire.id, floor: floorIndex))
                #expect(floor.floor == floorIndex)
                #expect(floor.spireID == spire.id)
            }
            #expect(GameContent.spireFloor(spireID: spire.id, floor: 0) == nil)
            #expect(GameContent.spireFloor(spireID: spire.id, floor: spire.floorCount + 1) == nil)
            #expect(GameContent.spireFloor(spireID: spire.id, floor: -1) == nil)
        }
    }

    @Test func `every floor rolls one stable modifier from its keyword pool`() throws {
        for spire in GameContent.spires {
            let pool = NodeModifierCatalog.keywordModifiers(for: spire.keyword, nodeType: .battle)
            #expect(pool.count == 3)
            #expect(Set(pool.map(\.id)).count == 3)
            #expect(NodeModifierCatalog.keywordModifiers(for: spire.keyword, nodeType: .boss) == pool)
            #expect(pool.contains { $0.effect == .damageDealt(keyword: spire.keyword, amount: 1) })
            #expect(pool.contains { $0.effect == .damageTakenReduction(keyword: spire.keyword, percent: 50) })
            #expect(pool.contains { $0.effect == .reward(.keyword(spire.keyword)) })

            for floor in GameContent.spireFloors(for: spire.id) {
                let first = try #require(GameContent.spireModifier(for: floor, worldSeed: 42))
                #expect(pool.contains(first))
                #expect(GameContent.spireModifier(for: floor, worldSeed: 42) == first)
            }

            let firstFloor = try #require(GameContent.spireFloor(spireID: spire.id, floor: 1))
            let seen = Set((0 ..< 96).compactMap { seed in
                GameContent.spireModifier(for: firstFloor, worldSeed: UInt64(seed))?.id
            })
            #expect(seen == Set(pool.map(\.id)))
        }
    }
}
