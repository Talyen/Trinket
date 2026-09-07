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

    @Test(arguments: [(20, 1, 17), (20, 15, 18), (20, 30, 20), (2, 1, 2), (1, 1, 1), (1000, 1, 997)])
    func `campaign keeps content floor`(authored: Int, party: Int, expected: Int) {
        #expect(EncounterLevelResolver.campaignAdjusted(authored, partyAverageLevel: party) == expected)
    }

    @Test(arguments: [(5, 1, 4), (6, 1, 6), (10, 1, 6), (11, 1, 11), (20, 1, 16), (20, 15, 18), (20, 30, 20), (1000, 1, 996)])
    func `labyrinth keeps depth band floor`(authored: Int, party: Int, expected: Int) {
        #expect(EncounterLevelResolver.labyrinthAdjusted(authored, partyAverageLevel: party) == expected)
    }

    @Test func `party ceiling does not overflow at representational limit`() {
        #expect(EncounterLevelResolver.campaignAdjusted(Int.max, partyAverageLevel: Int.max) == Int.max)
        #expect(EncounterLevelResolver.labyrinthAdjusted(Int.max, partyAverageLevel: Int.max) == Int.max)
    }
}
