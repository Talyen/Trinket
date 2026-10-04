import Foundation
import Testing
import TrinketContent
import TrinketCore

/// Bounty-contract generator tests (ContractGenerator.makeOffer). For manifest
/// catalog invariants, see GameContentCatalogInvariantTests.
struct ContractGeneratorTests {
    @Test(arguments: [ContractDifficulty.easy, .hard])
    func `contracts honor exclusions and fall back when the pool is exhausted`(difficulty: ContractDifficulty) throws {
        var rng = SeededRandomNumberGenerator(seed: 1772)
        let pool = GameContent.enemies.filter { $0.isBoss == difficulty.isBoss }
        let remaining = try #require(pool.first)
        let allIDs = Set(GameContent.enemies.map(\.id))
        let offer = ContractGenerator.makeOffer(
            difficulty: difficulty, excludingEnemyIDs: allIDs.subtracting([remaining.id]),
            eligibleModifiers: [.astral], using: &rng,
        )
        #expect(offer.enemyID == remaining.id)
        #expect(offer.rewardModifier == .astral)
        let fallback = ContractGenerator.makeOffer(
            difficulty: difficulty, excludingEnemyIDs: allIDs, eligibleModifiers: [], using: &rng,
        )
        #expect(pool.contains { $0.id == fallback.enemyID })
        #expect(fallback.rewardModifier == .gold)
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
    }

    @Test func `repeated targets receive independent offer identities`() throws {
        var rng = SeededRandomNumberGenerator(seed: 1772)
        let enemy = try #require(GameContent.bossEnemies.first)
        let excluded = Set(GameContent.bossEnemies.map(\.id)).subtracting([enemy.id])
        let first = ContractGenerator.makeOffer(difficulty: .hard, excludingEnemyIDs: excluded, using: &rng)
        let second = ContractGenerator.makeOffer(difficulty: .hard, excludingEnemyIDs: excluded, using: &rng)
        #expect(first.enemyID == second.enemyID)
        #expect(first.id != second.id)
    }
}
