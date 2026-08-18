import Testing
import TrinketContent

struct EncounterLevelResolverTests {
    @Test func journeyEnemyLevelSpansFiveLevelsPerChapter() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter(\.encounter.isCombat)

        let levels = battleStages.map { EncounterLevelResolver.journeyEnemyLevel(for: $0, in: chapter) }
        try #expect(levels.first == 1)
        try #expect(levels.last == 5)
        try #expect(levels == levels.sorted())
        try #expect(Set(levels).count == battleStages.count)
    }

    @Test func nonBattleStagesReturnChapterBaseLevel() throws {
        let chapter = try #require(GameContent.chapters.first)
        let nonBattleStage = try #require(chapter.stages.first {
            !$0.encounter.isCombat
        })

        try #expect(EncounterLevelResolver.journeyEnemyLevel(for: nonBattleStage, in: chapter) == 1)
    }

    @Test func spireEnemyLevelIsTwiceTheFloor() {
        let floor = SpireFloor(spireID: .ironVein, floor: 10, enemyID: "goblin")
        #expect(EncounterLevelResolver.spireEnemyLevel(for: floor) == 20)
        let first = SpireFloor(spireID: .ironVein, floor: 1, enemyID: "goblin")
        #expect(EncounterLevelResolver.spireEnemyLevel(for: first) == 2)
    }

    @Test func labyrinthEnemyLevelUsesNodeDepth() {
        let node = LabyrinthNode(id: "n1", type: .battle, depth: 7, clusterID: "c1")
        #expect(EncounterLevelResolver.labyrinthEnemyLevel(for: node) == 7)
        let floor = LabyrinthNode(id: "n0", type: .entrance, depth: 0, clusterID: "c1")
        #expect(EncounterLevelResolver.labyrinthEnemyLevel(for: floor) == 1)
    }
}
