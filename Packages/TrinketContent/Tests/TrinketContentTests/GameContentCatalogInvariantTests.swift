import Testing
@testable import TrinketContent

struct GameContentCatalogInvariantTests {
    /// Unlike manifest-generated IDs, authored Mystery/Recruit IDs are only scraped by codegen.
    @Test func `authored encounter I ds are unique across both pools`() {
        let ids = (GameContent.mysteryEvents + GameContent.recruitEvents).map(\.id)
        #expect(ids.count == Set(ids).count)
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
