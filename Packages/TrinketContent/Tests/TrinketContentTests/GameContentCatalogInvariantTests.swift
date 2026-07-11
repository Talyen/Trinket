import Testing
@testable import TrinketContent

struct GameContentCatalogInvariantTests {
    @Test func itemBaseIDsAreUnique() throws {
        let ids = GameContent.itemBaseTypes.map(\.id)
        try #expect(ids.count == Set(ids).count)
    }

    @Test(arguments: GameContent.chapters.flatMap(\.stages))
    func everyStageBattleReferencesKnownEnemy(stage: Stage) throws {
        let enemyIDs = Set(GameContent.enemies.map(\.id))
        if let enemyID = stage.encounter.battleEnemyID {
            try #expect(
                enemyIDs.contains(enemyID),
                "Stage \(stage.id) references unknown enemy \(enemyID)"
            )
        }
    }

    @Test(arguments: GameContent.chapters.flatMap(\.stages))
    func encounterArtManifestReferencesCatalogEntries(stage: Stage) throws {
        guard let artID = GameContent.encounterArtID(for: stage) else { return }
        try #require(
            ArtCatalog.encounterArtByID[artID] != nil,
            "Encounter art \(artID) for stage \(stage.id) is missing from ArtCatalog"
        )
        try #expect(
            !(GameContent.encounterArtTitle(for: stage)?.isEmpty ?? true),
            "Encounter art title should be set when art id is set for \(stage.id)"
        )
    }

    @Test(arguments: GameContent.chapters.flatMap(\.stages))
    func mysteryStagesReferenceKnownEvents(stage: Stage) throws {
        guard let eventID = stage.encounter.mysteryEventID else { return }
        let event = try #require(
            GameContent.mysteryEvent(matching: eventID),
            "Stage \(stage.id) references unknown mystery event \(eventID)"
        )
        if event.isRecruit {
            _ = try #require(GameContent.combatant(forMysteryEvent: event))
        }
    }
}
