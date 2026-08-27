import Testing
import TrinketCore
@testable import TrinketContent

struct GameContentTraitCatalogTests {
    @Test func everyEnemyReferencesKnownTrait() throws {
        let traitIDs = Set(GameContent.traits.map(\.id))
        for enemy in GameContent.enemies {
            try #expect(traitIDs.contains(enemy.traitID), "\(enemy.name) trait")
        }
    }

    @Test func traitDescriptionsAreNonEmpty() throws {
        for trait in GameContent.traits {
            try #expect(!trait.name.isEmpty, "Trait \(trait.id) needs a name")
            try #expect(!trait.description.isEmpty, "Trait \(trait.id) needs a description")
        }
    }

    @Test func bossesHaveNoDamageTakenPercentResists() throws {
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

    @Test func necromancerLeechChanceIsTenPercent() throws {
        let necromancer = try #require(GameContent.traits.first { $0.id == "necromancer_trait" })
        try #expect(necromancer.triggers.leechChancePercent == 0.10)
    }

    @Test func enemyVulnerabilitiesAreThirtyPercent() throws {
        for trait in GameContent.traits {
            for modifier in trait.modifiers {
                if case let .damageTakenVulnerability(_, amount) = modifier {
                    try #expect(amount == 0.30, "\(trait.name) vulnerability should be 30%")
                }
            }
        }
    }

    @Test func bossDamageAurasMatchTypedIdentity() throws {
        let golem = try #require(GameContent.traits.first { $0.id == "the_forge_golem_trait" })
        try #expect(golem.triggers.turnRandomDamageAllEnemiesKeywordA == .stun)
        try #expect(golem.triggers.turnRandomDamageAllEnemiesKeywordB == .burn)
        try #expect(golem.triggers.turnRandomDamageAllEnemiesAmount == 1)

        let bear = try #require(GameContent.traits.first { $0.id == "the_iron_bear_trait" })
        try #expect(bear.triggers.turnRandomDamageAllEnemiesKeywordA == .physical)
        try #expect(bear.triggers.turnRandomDamageAllEnemiesKeywordB == .stun)
        try #expect(bear.triggers.turnRandomDamageAllEnemiesAmount == 1)

        let treant = try #require(GameContent.traits.first { $0.id == "the_blight_treant_trait" })
        try #expect(treant.triggers.turnRandomDamageAllEnemiesKeywordA == .poison)
        try #expect(treant.triggers.turnRandomDamageAllEnemiesKeywordB == .bleed)
        try #expect(treant.triggers.turnRandomDamageAllEnemiesAmount == 1)

        let frostwarden = try #require(GameContent.traits.first { $0.id == "the_frostwarden_trait" })
        try #expect(frostwarden.triggers.turnFreezeDamageAllEnemies == 1)
        try #expect(frostwarden.triggers.turnRandomDamageAllEnemiesAmount == 0)

        let countess = try #require(GameContent.traits.first { $0.id == "the_blood_countess_trait" })
        try #expect(countess.triggers.turnRandomDamageAllEnemiesKeywordA == .bleed)
        try #expect(countess.triggers.turnRandomDamageAllEnemiesKeywordB == .bleed)
        try #expect(countess.triggers.turnRandomDamageAllEnemiesAmount == 1)

        let seraph = try #require(GameContent.traits.first { $0.id == "the_seraph_trait" })
        try #expect(seraph.triggers.turnRandomDamageAllEnemiesKeywordA == .holy)
        try #expect(seraph.triggers.turnRandomDamageAllEnemiesKeywordB == .holy)
        try #expect(seraph.triggers.turnRandomDamageAllEnemiesAmount == 1)

        let titan = try #require(GameContent.traits.first { $0.id == "the_stone_titan_trait" })
        try #expect(titan.triggers.turnRandomDamageAllEnemiesKeywordA == .stun)
        try #expect(titan.triggers.turnRandomDamageAllEnemiesKeywordB == .stun)
        try #expect(titan.triggers.turnRandomDamageAllEnemiesAmount == 1)
    }
}
