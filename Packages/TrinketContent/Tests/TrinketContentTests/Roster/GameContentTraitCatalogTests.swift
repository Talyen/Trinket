import Testing
import TrinketCore
@testable import TrinketContent

struct GameContentTraitCatalogTests {
    @Test func `every enemy references known trait`() throws {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            try #expect(!enemy.traitIDs.isEmpty)
            try #expect(Set(enemy.traitIDs).count == enemy.traitIDs.count)
            try #expect(enemy.traitIDs.allSatisfy(traitIDs.contains), "\(enemy.name) traits")
            try #expect(GameContent.traits(for: enemy).map(\.id) == enemy.traitIDs)
        }
    }

    @Test func `bosses have no damage taken percent resists`() throws {
        for enemy in GameContent.enemies where enemy.isBoss {
            let traits = GameContent.traits(for: enemy)
            let resists = traits.flatMap(\.modifiers).contains { modifier in
                switch modifier {
                case .damageTakenPercent:
                    true
                default:
                    false
                }
            }
            try #expect(!resists, "\(enemy.name) should not resist a damage type")
        }
    }
}
