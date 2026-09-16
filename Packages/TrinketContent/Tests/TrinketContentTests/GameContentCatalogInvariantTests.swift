import Testing
@testable import TrinketContent

struct GameContentCatalogInvariantTests {
    @Test func `item base I ds are unique`() throws {
        let ids = GameContent.itemBaseTypes.map(\.id)
        try #expect(ids.count == Set(ids).count)
    }

    @Test func `catalog I ds are unique`() throws {
        let catalogs: [[String]] = [
            GameContent.itemAffixDefinitions.map(\.id),
            GameContent.traits.map(\.id),
            (GameContent.mysteryEvents + GameContent.recruitEvents).map(\.id),
        ]
        for ids in catalogs {
            try #expect(ids.count == Set(ids).count)
        }
    }

    @Test func `sfx catalog index matches clips`() throws {
        try #expect(SFXCatalog.clipsByID.count == SFXCatalog.clips.count)
        for clip in SFXCatalog.clips {
            try #expect(SFXCatalog.clipsByID[clip.id] == clip, "Missing SFX catalog index entry \(clip.id)")
        }
    }

    @Test func `every stage references known encounter content`() throws {
        let enemyIDs = Set(GameContent.enemies.map(\.id))
        for stage in GameContent.chapters.flatMap(\.stages) {
            if let enemyID = stage.encounter.battleEnemyID {
                try #expect(
                    enemyIDs.contains(enemyID),
                    "Stage \(stage.id) references unknown enemy \(enemyID)",
                )
            }
            if let eventID = stage.encounter.mysteryEventID {
                _ = try #require(
                    GameContent.mysteryEvent(matching: eventID),
                    "Stage \(stage.id) references unknown mystery event \(eventID)",
                )
            }
            if let eventID = stage.encounter.recruitEventID,
               !eventID.isEmpty,
               eventID != StageEncounter.randomCompanionRecruitID {
                let event = try #require(
                    GameContent.recruitEvent(matching: eventID),
                    "Stage \(stage.id) references unknown recruit event \(eventID)",
                )
                _ = try #require(GameContent.combatant(forMysteryEvent: event))
            }
        }
    }
}
