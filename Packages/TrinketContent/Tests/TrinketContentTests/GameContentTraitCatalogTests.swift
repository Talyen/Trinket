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
        try #expect(necromancer.description == "10% chance to Leech. Holy damage taken increased by 30%.")
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

    @Test func bossDamageRampsMatchTypedIdentity() throws {
        let golem = try #require(GameContent.traits.first { $0.id == "the_forge_golem_trait" })
        try #expect(golem.description == "Gains Stun or Burn damage each turn.")
        try #expect(!golem.triggers.damageIncreasesEveryOtherTurn)
        try #expect(golem.triggers.randomDamageRampKeywordA == .stun)
        try #expect(golem.triggers.randomDamageRampKeywordB == .burn)
        try #expect(golem.triggers.randomDamageRampPerTurn == 1)

        let bear = try #require(GameContent.traits.first { $0.id == "the_iron_bear_trait" })
        try #expect(bear.description == "Gains Physical or Stun damage each turn.")
        try #expect(!bear.triggers.damageIncreasesEveryOtherTurn)
        try #expect(bear.triggers.randomDamageRampKeywordA == .physical)
        try #expect(bear.triggers.randomDamageRampKeywordB == .stun)
        try #expect(bear.triggers.randomDamageRampPerTurn == 1)

        let treant = try #require(GameContent.traits.first { $0.id == "the_blight_treant_trait" })
        try #expect(treant.description == "Holy damage taken increased by 30%. Gains Poison or Bleed damage each turn.")
        try #expect(!treant.triggers.damageIncreasesEveryOtherTurn)
        try #expect(treant.triggers.randomDamageRampKeywordA == .poison)
        try #expect(treant.triggers.randomDamageRampKeywordB == .bleed)
        try #expect(treant.triggers.randomDamageRampPerTurn == 1)

        let frostwarden = try #require(GameContent.traits.first { $0.id == "the_frostwarden_trait" })
        try #expect(
            frostwarden.description
                == "Deals 1 Freeze damage every other turn to all enemies. Burn damage taken increased by 30%. Gains Freeze damage every other turn."
        )
        try #expect(frostwarden.triggers.damageIncreasesEveryOtherTurn)
        try #expect(frostwarden.triggers.damageIncreasesEveryOtherTurnKeyword == .freeze)
        try #expect(frostwarden.triggers.randomDamageRampPerTurn == 0)
        try #expect(frostwarden.triggers.turnFreezeDamageAllEnemies == 1)
    }
}
