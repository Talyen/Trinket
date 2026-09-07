import Testing
import TrinketContent
import TrinketCore

struct ContractsTests {
    @Test(arguments: ContractDifficulty.allCases)
    func `every matching catalog enemy can be contracted`(difficulty: ContractDifficulty) {
        var rng = SeededRandomNumberGenerator(seed: 1772)
        let allIDs = Set(GameContent.enemies.map(\.id))
        for enemy in GameContent.enemies where enemy.isBoss == difficulty.isBoss {
            let offer = ContractGenerator.makeOffer(
                difficulty: difficulty,
                excludingEnemyIDs: allIDs.subtracting([enemy.id]),
                using: &rng,
            )
            #expect(offer.enemyID == enemy.id)
            #expect(offer.difficulty == difficulty)
        }
    }

    @Test func `repeated targets receive independent offer identities`() {
        var rng = SeededRandomNumberGenerator(seed: 1772)
        let first = ContractGenerator.makeOffer(difficulty: .hard, using: &rng)
        let second = ContractGenerator.makeOffer(difficulty: .hard, using: &rng)
        #expect(first.id != second.id)
    }

    @Test(arguments: [(1, 1, 1, 4), (20, 17, 20, 23), (1000, 997, 1000, 1003)])
    func `contract levels follow party offsets`(party: Int, easy: Int, standard: Int, hard: Int) {
        #expect(EncounterLevelResolver.contractEnemyLevel(difficulty: .easy, partyAverageLevel: party) == easy)
        #expect(EncounterLevelResolver.contractEnemyLevel(difficulty: .standard, partyAverageLevel: party) == standard)
        #expect(EncounterLevelResolver.contractEnemyLevel(difficulty: .hard, partyAverageLevel: party) == hard)
    }
}
