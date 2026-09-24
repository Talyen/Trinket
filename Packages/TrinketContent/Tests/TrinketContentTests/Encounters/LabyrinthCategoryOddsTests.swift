import Testing
import TrinketContent
import TrinketCore

@Suite("Labyrinth modifier category odds")
struct LabyrinthCategoryOddsTests {
    @Test func `new combat rules preserve the original reward category odds`() throws {
        let originalDamageBonuses: Set<Keyword> = [.physical, .burn, .bleed, .poison, .freeze, .holy, .stun]
        for enemy in GameContent.enemies {
            let keywords = LabyrinthCatalog.enemyDamageKeywords(for: enemy.id)
            let originalCombatCount = 2 + keywords.intersection(originalDamageBonuses).count
                + (keywords.contains(.physical) ? 1 : 0) + (keywords.contains(.freeze) ? 1 : 0)
            for seed in 0 ..< 32 {
                var expectedRNG = SeededRandomNumberGenerator(seed: UInt64(seed))
                let expectsReward = Int.random(in: 0 ..< originalCombatCount + 3, using: &expectedRNG) < 3
                var actualRNG = SeededRandomNumberGenerator(seed: UInt64(seed))
                let id = try #require(LabyrinthCatalog.pickModifier(
                    for: .battle, enemyID: enemy.id, using: &actualRNG,
                ))
                let modifier = try #require(LabyrinthCatalog.modifier(id: id))
                let isReward = switch modifier.effect {
                case .reward:
                    true
                default:
                    false
                }
                #expect(isReward == expectsReward)
            }
        }
    }
}
