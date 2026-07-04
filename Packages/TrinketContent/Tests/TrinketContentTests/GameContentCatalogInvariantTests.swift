import XCTest
@testable import TrinketContent

final class GameContentCatalogInvariantTests: XCTestCase {
    func testItemBaseIDsAreUnique() {
        let ids = GameContent.itemBaseTypes.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryStageBattleReferencesKnownEnemy() {
        let enemyIDs = Set(GameContent.enemies.map(\.id))
        for stage in GameContent.chapters.flatMap(\.stages) {
            if let enemyID = stage.encounter.battleEnemyID {
                XCTAssertTrue(
                    enemyIDs.contains(enemyID),
                    "Stage \(stage.id) references unknown enemy \(enemyID)"
                )
            }
        }
    }

    func testEncounterArtManifestReferencesCatalogEntries() {
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                guard let artID = GameContent.encounterArtID(for: stage) else { continue }
                XCTAssertNotNil(
                    ArtCatalog.encounterArtByID[artID],
                    "Encounter art \(artID) for stage \(stage.id) is missing from ArtCatalog"
                )
                XCTAssertFalse(
                    GameContent.encounterArtTitle(for: stage)?.isEmpty ?? true,
                    "Encounter art title should be set when art id is set for \(stage.id)"
                )
            }
        }
    }
}
