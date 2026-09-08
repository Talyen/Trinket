import Testing
import TrinketCore
@testable import TrinketContent

struct GameContentTraitCatalogTests {
    @Test func `every enemy references known trait`() throws {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            try #expect(traitIDs.contains(enemy.traitID), "\(enemy.name) trait")
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
            let trait = try #require(GameContent.trait(for: enemy))
            let resists = trait.modifiers.contains { modifier in
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
        let necromancer = try #require(GameContent.traits.first { $0.id == "necromancer_trait" })
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
        try checkAura(id: "the_forge_golem_trait", keywordA: .stun, keywordB: .burn, amount: 1)
        try checkAura(id: "the_iron_bear_trait", keywordA: .physical, keywordB: .stun, amount: 1)
        try checkAura(id: "the_blight_treant_trait", keywordA: .poison, keywordB: .bleed, amount: 1)
        try checkAura(id: "the_blood_countess_trait", keywordA: .bleed, keywordB: .bleed, amount: 1)
        try checkAura(id: "the_seraph_trait", keywordA: .holy, keywordB: .holy, amount: 1)
        try checkAura(id: "the_stone_titan_trait", keywordA: .stun, keywordB: .stun, amount: 1)

        let frostwarden = try #require(GameContent.traits.first { $0.id == "the_frostwarden_trait" })
        try #expect(frostwarden.triggers.turnFreezeDamageAllEnemies == 1)
        try #expect(frostwarden.triggers.turnRandomDamageAllEnemiesAmount == 0)
    }

    private func checkAura(id: String, keywordA: Keyword, keywordB: Keyword, amount: Int) throws {
        let trait = try #require(GameContent.traits.first { $0.id == id })
        try #expect(trait.triggers.turnRandomDamageAllEnemiesKeywordA == keywordA)
        try #expect(trait.triggers.turnRandomDamageAllEnemiesKeywordB == keywordB)
        try #expect(trait.triggers.turnRandomDamageAllEnemiesAmount == amount)
    }
}
