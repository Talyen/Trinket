import Testing
import TrinketContent
import TrinketCore

@Suite("AspectCatalog")
struct AspectCatalogTests {
    @Test func damageAspectsAreAuthored() throws {
        try #expect(GameContent.aspects.count == 8)
        for aspect in GameContent.aspects {
            try #expect(aspect.keyword.category == .damageType)
            try #expect(!aspect.title.isEmpty)
            try #expect(aspect.title != aspect.keyword.rawValue)
            try #expect(GameContent.aspectFloors(for: aspect.id).count == aspect.floorCount)
        }
    }

    @Test func floorsResolveExistingEnemies() throws {
        for aspect in GameContent.aspects {
            for floor in GameContent.aspectFloors(for: aspect.id) {
                try #expect(GameContent.enemy(matching: floor.enemyID) != nil, "Missing enemy \(floor.enemyID)")
                try #expect(floor.rewards.gold > 0)
            }
            let warden = try #require(GameContent.aspectFloor(aspectID: aspect.id, floor: aspect.floorCount))
            try #expect(warden.isWarden)
        }
    }

    @Test func attunementRequiresMatchingAbilityKeywords() throws {
        let ironVein = try #require(GameContent.aspect(id: .ironVein))
        let knight = try #require(GameContent.heroes.first { $0.id == "knight" })
        let bear = try #require(GameContent.pets.first { $0.id == "bear" })
        let frostWhelp = try #require(GameContent.pets.first { $0.id == "frost_whelp" })

        try #expect(AspectAttunement.evaluate(hero: knight, pet: bear, aspect: ironVein) == .ready)
        try #expect(
            AspectAttunement.evaluate(hero: knight, pet: frostWhelp, aspect: ironVein)
                == .missingPetAffinity
        )
    }
}
