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

    @Test func `trait descriptions are non empty`() throws {
        for trait in GameContent.traits {
            try #expect(!trait.name.isEmpty, "Trait \(trait.id) needs a name")
            try #expect(!trait.description.isEmpty, "Trait \(trait.id) needs a description")
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

    @Test func `traits use distinct mechanic names instead of enemy names`() {
        let names = GameContent.traits.map { $0.name.lowercased() }
        let enemyNames = Set(GameContent.enemies.map { $0.name.lowercased() })
        #expect(Set(names).count == names.count)
        #expect(enemyNames.isDisjoint(with: names))
        #expect(Set(GameContent.enemies.flatMap(\.traitIDs)) == Set(GameContent.traits.map(\.id)))
    }
}
