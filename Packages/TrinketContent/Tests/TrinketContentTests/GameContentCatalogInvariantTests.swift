import Testing
@testable import TrinketContent

@Suite struct GameContentCatalogInvariantTests {
    @Test func itemBaseIDsAreUnique() {
        let ids = GameContent.itemBaseTypes.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test(arguments: GameContent.chapters.flatMap(\.stages))
    func everyStageBattleReferencesKnownEnemy(stage: Stage) {
        let enemyIDs = Set(GameContent.enemies.map(\.id))
        if let enemyID = stage.encounter.battleEnemyID {
            #expect(
                enemyIDs.contains(enemyID),
                "Stage \(stage.id) references unknown enemy \(enemyID)"
            )
        }
    }

    @Test(arguments: GameContent.chapters.flatMap(\.stages))
    func encounterArtManifestReferencesCatalogEntries(stage: Stage) {
        guard let artID = GameContent.encounterArtID(for: stage) else { return }
        #expect(
            ArtCatalog.encounterArtByID[artID] != nil,
            "Encounter art \(artID) for stage \(stage.id) is missing from ArtCatalog"
        )
        #expect(
            !(GameContent.encounterArtTitle(for: stage)?.isEmpty ?? true),
            "Encounter art title should be set when art id is set for \(stage.id)"
        )
    }
}
