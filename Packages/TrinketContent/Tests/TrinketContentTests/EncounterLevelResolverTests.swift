import Testing
import TrinketContent

@Suite
struct EncounterLevelResolverTests {
    @Test func journeyEnemyLevelSpansFiveLevelsPerChapter() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter {
            if case .battle = $0.encounter { return true }
            return false
        }

        let levels = battleStages.map { EncounterLevelResolver.journeyEnemyLevel(for: $0, in: chapter) }
        try #expect(levels.first == 1)
        try #expect(levels.last == 5)
        try #expect(levels == levels.sorted())
        try #expect(Set(levels).count >= 4)
    }

    @Test func nonBattleStagesReturnChapterBaseLevel() throws {
        let chapter = try #require(GameContent.chapters.first)
        let eventStage = try #require(chapter.stages.first { if case .event = $0.encounter { return true } else { return false } })

        try #expect(EncounterLevelResolver.journeyEnemyLevel(for: eventStage, in: chapter) == 1)
    }
}
