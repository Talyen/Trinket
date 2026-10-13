import Testing
import TrinketCore
@testable import TrinketContent

struct EncounterBoardTests {
    @Test func `Contract generation repair and refresh preserve the three slot rules`() {
        let choices = RewardModifier.allCases
        let original = ContractBoard.preparedOffers([], excluding: [], eligibleModifiers: choices)
        #expect(ContractBoard.preparedOffers(original, excluding: [], eligibleModifiers: choices) == original)
        #expect(original.map(\.difficulty) == ContractDifficulty.allCases)
        #expect(Set(original.map(\.enemyID)).count == 3)
        for offer in original {
            #expect(GameContent.enemy(matching: offer.enemyID)?.isBoss == offer.difficulty.isBoss)
        }
        let refreshed = ContractBoard.refreshedOffers(replacing: original, eligibleModifiers: choices)
        for offer in refreshed {
            #expect(offer.id != original.first { $0.difficulty == offer.difficulty }?.id)
            #expect(offer.enemyID != original.first { $0.difficulty == offer.difficulty }?.enemyID)
        }
        let retained = refreshed.filter { $0.difficulty != .easy }
        let repaired = ContractBoard.preparedOffers(retained + [
            ContractOffer(id: "invalid", difficulty: .easy, enemyID: "missing-enemy"),
        ], excluding: [], eligibleModifiers: choices)
        #expect(repaired.count == 3)
        #expect(repaired.filter { $0.difficulty != .easy } == retained)
        #expect(Set(repaired.map(\.enemyID)).count == 3)
    }

    @Test func `Voyage boards retain accessible destinations and replace only retired slots`() throws {
        var rng = SeededRandomNumberGenerator(seed: 17)
        let choices: [RewardModifier] = [.gold, .experience, .wood]
        let original = VoyageBoard.preparedOffers([], excluding: [], access: .free, eligibleModifiers: choices, using: &rng)
        #expect(Set(original.map(\.chapterID)) == ["chapter-1", "chapter-2", "chapter-3"])
        #expect(original.map(\.difficulty) == VoyageDifficulty.allCases)
        #expect(Set(original.map(\.rewardModifier)) == Set(choices))
        #expect(VoyageBoard.preparedOffers(original, excluding: [], access: .free, eligibleModifiers: choices, using: &rng) == original)
        let retired = try #require(original.first)
        let replaced = VoyageBoard.preparedOffers(
            original, excluding: [retired.id], access: .free, eligibleModifiers: choices, using: &rng,
        )
        #expect(replaced.first?.id != retired.id)
        #expect(replaced.first?.difficulty == retired.difficulty)
        #expect(Array(replaced.dropFirst()) == Array(original.dropFirst()))
        #expect(Set(replaced.map(\.rewardModifier)) == Set(choices))
    }
}
