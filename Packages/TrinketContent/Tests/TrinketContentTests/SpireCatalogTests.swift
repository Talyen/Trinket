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
            }
            let finalFloor = try #require(GameContent.spireFloor(spireID: spire.id, floor: spire.floorCount))
            try #expect(GameContent.enemy(matching: finalFloor.enemyID)?.isBoss == true)
        }
    }

    @Test func `attunement requires matching ability keywords`() throws {
        let ironVein = try #require(GameContent.spire(id: .ironVein))
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let frostWhelp = try #require(GameContent.companions.first { $0.id == "frost_whelp" })

        try #expect(SpireAttunement.matches(rogue, spire: ironVein))
        try #expect(SpireAttunement.matches(bear, spire: ironVein))
        try #expect(!SpireAttunement.matches(frostWhelp, spire: ironVein))
        try #expect(
            SpireAttunement.canEnter(ironVein, heroes: [rogue], companions: [bear, frostWhelp]),
        )
        try #expect(
            !SpireAttunement.canEnter(ironVein, heroes: [rogue], companions: [frostWhelp]),
        )
        try #expect(SpireAttunement.evaluate(hero: rogue, companion: bear, spire: ironVein) == .ready)
        try #expect(
            SpireAttunement.evaluate(hero: rogue, companion: frostWhelp, spire: ironVein)
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
}
