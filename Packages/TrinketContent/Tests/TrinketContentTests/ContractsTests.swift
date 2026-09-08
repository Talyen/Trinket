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
}
