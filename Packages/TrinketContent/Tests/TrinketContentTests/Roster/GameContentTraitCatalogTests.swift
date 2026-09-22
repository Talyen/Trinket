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

    @Test func `necromancer leech chance is ten percent`() throws {
        let necromancer = try #require(GameContent.traits.first { $0.id == "siphon" })
        try #expect(necromancer.triggers.leechChancePercent == 0.10)
    }

    @Test func `enemy vulnerabilities are thirty percent`() throws {
        for trait in GameContent.traits {
            for modifier in trait.modifiers {
                if case let .damageTakenVulnerability(_, amount) = modifier {
                    try #expect(amount == 0.30, "\(trait.name) vulnerability should be 30%")
                }
            }
        }
    }

    @Test func `boss damage auras match typed identity`() throws {
        try checkAura(id: "furnace_pulse", keywordA: .stun, keywordB: .burn, amount: 1)
        try checkAura(id: "thunderous_tremor", keywordA: .physical, keywordB: .stun, amount: 1)
        try checkAura(id: "blighted_pulse", keywordA: .poison, keywordB: .bleed, amount: 1)
        try checkAura(id: "crimson_pulse", keywordA: .bleed, keywordB: .bleed, amount: 1)
        try checkAura(id: "radiant_judgment", keywordA: .holy, keywordB: .holy, amount: 1)
        try checkAura(id: "seismic_pulse", keywordA: .physical, keywordB: .physical, amount: 1)

        let frostwarden = try #require(GameContent.traits.first { $0.id == "winters_grasp" })
        try #expect(frostwarden.triggers.turnFreezeDamageAllEnemies == 1)
        try #expect(frostwarden.triggers.turnRandomDamageAllEnemiesAmount == 0)
    }

    @Test func `traits use distinct mechanic names instead of enemy names`() {
        let names = GameContent.traits.map { $0.name.lowercased() }
        let enemyNames = Set(GameContent.enemies.map { $0.name.lowercased() })
        #expect(Set(names).count == names.count)
        #expect(enemyNames.isDisjoint(with: names))
        #expect(Set(GameContent.enemies.flatMap(\.traitIDs)) == Set(GameContent.traits.map(\.id)))
    }

    @Test func `enemies share matching mechanics and display each effect separately`() throws {
        let expected: [String: [String]] = [
            "fire_elemental": ["searing_body", "cold_shocked"],
            "vampire": ["siphon", "sated_fury", "profane", "kindling"],
            "living_armor": ["watchful_guard", "bloodless"],
            "paladin": ["righteous_guard", "hallowed"],
            "frost_elemental": ["chilling_strikes", "kindling"],
            "winter_wolf": ["chilling_strikes", "kindling"],
        ]
        for (id, traitIDs) in expected {
            let enemy = try #require(GameContent.enemy(matching: id))
            #expect(enemy.traitIDs == traitIDs)
        }
    }

    private func checkAura(id: String, keywordA: Keyword, keywordB: Keyword, amount: Int) throws {
        let trait = try #require(GameContent.traits.first { $0.id == id })
        try #expect(trait.triggers.turnRandomDamageAllEnemiesKeywordA == keywordA)
        try #expect(trait.triggers.turnRandomDamageAllEnemiesKeywordB == keywordB)
        try #expect(trait.triggers.turnRandomDamageAllEnemiesAmount == amount)
    }
}
