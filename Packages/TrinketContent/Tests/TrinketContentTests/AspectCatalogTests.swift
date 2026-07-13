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
        let rogue = try #require(GameContent.heroes.first { $0.id == "rogue" })
        let bear = try #require(GameContent.companions.first { $0.id == "bear" })
        let frostWhelp = try #require(GameContent.companions.first { $0.id == "frost_whelp" })

        try #expect(AspectAttunement.evaluate(hero: rogue, companion: bear, aspect: ironVein) == .ready)
        try #expect(
            AspectAttunement.evaluate(hero: rogue, companion: frostWhelp, aspect: ironVein)
                == .missingCompanionAffinity
        )
    }

    @Test func everyAspectHasAttunableHeroAndCompanion() throws {
        for aspect in GameContent.aspects {
            let heroes = GameContent.heroes.filter { $0.keywordProfile.contains(aspect.keyword) }
            let companions = GameContent.companions.filter { $0.keywordProfile.contains(aspect.keyword) }
            try #expect(!heroes.isEmpty, "\(aspect.title) needs a Hero with \(aspect.keyword.rawValue)")
            try #expect(!companions.isEmpty, "\(aspect.title) needs a Companion with \(aspect.keyword.rawValue)")
            let ready = heroes.contains { hero in
                companions.contains { companion in
                    AspectAttunement.evaluate(hero: hero, companion: companion, aspect: aspect) == .ready
                }
            }
            try #expect(ready, "\(aspect.title) needs at least one ready Hero+Companion pair")
        }
    }
}
