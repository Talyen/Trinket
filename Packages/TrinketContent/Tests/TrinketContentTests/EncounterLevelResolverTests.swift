import Testing
import TrinketContent

struct EncounterLevelResolverTests {
    @Test func `journey enemy level spans five levels per chapter`() throws {
        let chapter = try #require(GameContent.chapters.first)
        let battleStages = chapter.stages.filter(\.encounter.isCombat)

        let levels = battleStages.map { EncounterLevelResolver.journeyEnemyLevel(for: $0, in: chapter) }
        try #expect(levels.first == 1)
        try #expect(levels.last == 5)
        try #expect(levels == levels.sorted())
        try #expect(Set(levels).count == battleStages.count)
    }

    @Test func `non battle stages return chapter base level`() throws {
        let chapter = try #require(GameContent.chapters.first)
        let nonBattleStage = try #require(chapter.stages.first {
            !$0.encounter.isCombat
        })

        try #expect(EncounterLevelResolver.journeyEnemyLevel(for: nonBattleStage, in: chapter) == 1)
    }

    @Test func `spire enemy level is twice the floor`() {
        let floor = SpireFloor(spireID: .ironVein, floor: 10, enemyID: "goblin")
        #expect(EncounterLevelResolver.spireEnemyLevel(for: floor) == 20)
        let first = SpireFloor(spireID: .ironVein, floor: 1, enemyID: "goblin")
        #expect(EncounterLevelResolver.spireEnemyLevel(for: first) == 2)
    }

    @Test func `labyrinth enemy level uses node depth`() {
        let node = LabyrinthNode(id: "n1", type: .battle, depth: 7, clusterID: "c1")
        #expect(EncounterLevelResolver.labyrinthEnemyLevel(for: node) == 7)
        let floor = LabyrinthNode(id: "n0", type: .entrance, depth: 0, clusterID: "c1")
        #expect(EncounterLevelResolver.labyrinthEnemyLevel(for: floor) == 1)
    }

    @Test func `party adjusted never exceeds authored level`() {
        #expect(EncounterLevelResolver.partyAdjusted(20, partyAverageLevel: 30) == 20)
        #expect(EncounterLevelResolver.partyAdjusted(2, partyAverageLevel: 1) == 2)
    }

    @Test func `party adjusted caps underleveled parties at average plus offset`() {
        #expect(EncounterLevelResolver.downwardPartyOffset == 3)
        #expect(EncounterLevelResolver.partyAdjusted(30, partyAverageLevel: 10) == 13)
        #expect(EncounterLevelResolver.partyAdjusted(14, partyAverageLevel: 10) == 13)
        #expect(EncounterLevelResolver.partyAdjusted(13, partyAverageLevel: 10) == 13)
    }
}
