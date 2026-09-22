import Foundation
import Testing
import TrinketContent
import TrinketCore

/// Bounty-contract generator tests (ContractGenerator.makeOffer). For manifest
/// catalog invariants, see GameContentCatalogInvariantTests; for test-fixture
/// pins, see FixtureContractTests.
struct ContractGeneratorTests {
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

    @Test func `legacy offers retain identity and receive a gold modifier`() throws {
        let data = Data(#"{"id":"legacy","difficulty":"hard","enemyID":"boss"}"#.utf8)
        let offer = try JSONDecoder().decode(ContractOffer.self, from: data)
        #expect(offer.id == "legacy")
        #expect(offer.enemyID == "boss")
        #expect(offer.difficulty == .hard)
        #expect(offer.rewardModifier == .gold)
        #expect(try JSONDecoder().decode(ContractOffer.self, from: JSONEncoder().encode(offer)) == offer)
    }

    @Test func `exhausted collectible pools are excluded and saved bonuses fall back to gold`() {
        let trinkets = Set(GameContent.trinketItems.map(\.templateID))
        let uniques = Set(GameContent.uniqueItems.map(\.templateID))
        let eligible = RewardModifier.eligible(ownedTrinketIDs: trinkets, ownedUniqueIDs: uniques)
        #expect(!eligible.contains(.trinket))
        #expect(!eligible.contains(.unique))
        #expect(eligible.contains(.astral))
        #expect(RewardModifier.trinket.resolved(ownedTrinketIDs: trinkets, ownedUniqueIDs: []) == .gold)
        #expect(RewardModifier.unique.resolved(ownedTrinketIDs: [], ownedUniqueIDs: uniques) == .gold)
        var rng = SeededRandomNumberGenerator(seed: 1772)
        for difficulty in ContractDifficulty.allCases {
            for modifier in eligible {
                let offer = ContractGenerator.makeOffer(difficulty: difficulty, eligibleModifiers: [modifier], using: &rng)
                #expect(offer.rewardModifier == modifier)
            }
        }
    }

    @Test func `repeated targets receive independent offer identities`() {
        var rng = SeededRandomNumberGenerator(seed: 1772)
        let first = ContractGenerator.makeOffer(difficulty: .hard, using: &rng)
        let second = ContractGenerator.makeOffer(difficulty: .hard, using: &rng)
        #expect(first.id != second.id)
    }
}
