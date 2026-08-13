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
}
