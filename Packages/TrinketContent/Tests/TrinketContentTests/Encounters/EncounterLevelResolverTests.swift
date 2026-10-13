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
        #expect(EncounterScaling.journey(authoredLevel: authored).resolve(partyAverageLevel: party).level == expected)
    }

    @Test(arguments: [(5, 1, 4), (6, 1, 6), (10, 1, 6), (11, 1, 11), (20, 1, 16), (20, 15, 18), (20, 30, 20), (1000, 1, 996)])
    func `labyrinth keeps depth band floor`(authored: Int, party: Int, expected: Int) {
        #expect(EncounterScaling.labyrinth(authoredLevel: authored).resolve(partyAverageLevel: party).level == expected)
    }

    @Test func `party ceiling does not overflow at representational limit`() {
        #expect(EncounterScaling.journey(authoredLevel: Int.max).resolve(partyAverageLevel: Int.max).level == Int.max)
        #expect(EncounterScaling.labyrinth(authoredLevel: Int.max).resolve(partyAverageLevel: Int.max).level == Int.max)
    }

    @Test func `Voyage offsets preserve usable levels at saved progression limits`() {
        #expect(EncounterScaling.voyage(.hard).resolve(partyAverageLevel: Int.max).level == Int.max)
        #expect(EncounterScaling.voyage(.medium).resolve(partyAverageLevel: Int.max).level == Int.max)
        #expect(EncounterScaling.voyage(.easy).resolve(partyAverageLevel: Int.max).level == Int.max - 3)
        #expect(EncounterScaling.voyage(.easy).resolve(partyAverageLevel: Int.min).level == 1)
    }

    @Test(arguments: [(1, 1, 1, 4), (20, 17, 20, 23), (1000, 997, 1000, 1003)])
    func `contract levels follow party offsets`(party: Int, easy: Int, standard: Int, hard: Int) {
        let easyScaling = EncounterScaling.contract(.easy).resolve(partyAverageLevel: party)
        let standardScaling = EncounterScaling.contract(.standard).resolve(partyAverageLevel: party)
        let hardScaling = EncounterScaling.contract(.hard).resolve(partyAverageLevel: party)
        #expect(easyScaling.level == easy)
        #expect(standardScaling.level == standard)
        #expect(hardScaling.level == hard)
        #expect(easyScaling.profile == .recovery)
        #expect(standardScaling.profile == .standard)
        #expect(hardScaling.profile == .standard)
    }
}
