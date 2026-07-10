import Testing
import TrinketCore
import TrinketContent

@Suite
struct AbilityCatalogTests {
    @Test func catalogIDsAreUnique() throws {
        let ids = AbilityCatalog.all.map(\.id)
        try #expect(Set(ids).count == ids.count, "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)")
    }

    @Test func unknownAbilityLookupReturnsNil() throws {
        try #expect(AbilityCatalog.ability(id: "missing-ability") == nil)
    }

    @Test func staticReexportsMatchCatalog() throws {
        try #expect(Ability.fireball == AbilityCatalog.ability(id: Ability.fireball.id))
        try #expect(Ability.bloodthorn == AbilityCatalog.ability(id: Ability.bloodthorn.id))
        try #expect(Ability.slash == AbilityCatalog.ability(id: Ability.slash.id))
    }

    @Test func doTPairingMatchesDamageComponents() throws {
        for ability in AbilityCatalog.all {
            if ["mana-berries", "pixie-dust"].contains(ability.id) {
                continue
            }
            for component in ability.damageComponents where component.target == .abilityTarget {
                switch component.keyword {
                case .burn:
                    try #expect(
                        ability.effects.contains {
                            if case let .burn(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Burn damage with .burn(\(component.amount))"
                    )
                case .poison:
                    try #expect(
                        ability.effects.contains {
                            if case let .poison(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Poison damage with .poison(\(component.amount))"
                    )
                case .bleed:
                    try #expect(
                        ability.effects.contains {
                            if case let .bleed(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Bleed damage with .bleed(\(component.amount))"
                    )
                default:
                    continue
                }
            }
        }
    }

    @Test func bloodthornUsesDamageComponents() throws {
        try #expect(Ability.bloodthorn.damageComponents.count == 3)
        try #expect(Ability.bloodthorn.directDamage == 6)
        try #expect(Ability.fireball.directDamage == 2)
        try #expect(Ability.fireball.damageKeyword == .burn)
    }

    @Test func catalogPassesValidation() throws {
        let issues = AbilityValidator.validateCatalog()
        try #expect(issues.isEmpty, "\(issues.map(\.description).joined(separator: "\n"))")
    }

    @Test func abilityBuilderMatchesDirectHitPattern() throws {
        let built = AbilityBuilder.directHit(
            id: "fireball",
            name: "Fireball",
            tier: .skill,
            amount: 2,
            keyword: .burn
        )
        try #expect(built.damageComponents == Ability.fireball.damageComponents)
        try #expect(built.targetedEffects == Ability.fireball.targetedEffects)
        try #expect(built.summary == Ability.fireball.summary)
    }

    @Test func directHitBuilderAddsPairedDoT() throws {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn
        )
        try #expect(ability.damageComponents == [DamageComponent(3, keyword: .burn)])
        try #expect(ability.effects.contains { if case .burn(3) = $0 { return true }; return false })
        try #expect(ability.summary == "Deal 3 Burn damage.")
    }

    @Test func buffOnlyBuilderProducesGeneratedDescription() throws {
        let ability = AbilityBuilder.buffOnly(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2, 6)]
        )
        try #expect(ability.summary == "Gain 2 Block for 6 seconds.")
    }

    @Test func multiDamageBuilderFormatsSummary() throws {
        let ability = AbilityBuilder.multiDamage(
            id: "bloodthorn",
            name: "Bloodthorn",
            tier: .ultimate,
            damageComponents: [
                DamageComponent(2, keyword: .nature),
                DamageComponent(2, keyword: .bleed),
                DamageComponent(2, keyword: .poison)
            ],
            effects: [
                TargetedEffect(.bleed(2)),
                TargetedEffect(.poison(2))
            ],
            hasLeech: true
        )
        try #expect(
            ability.summary == "Deal 2 Nature damage, Deal 2 Bleed damage and Deal 2 Poison damage. Leech."
        )
    }

    @Test func hemorrhageFormatsBleedDamageWithLeechKeyword() throws {
        try #expect(Ability.hemorrhage.summary == "Deal 6 Bleed damage. Leech.")
        try #expect(Ability.hemorrhage.hasLeech)
        try #expect(Ability.hemorrhage.criticalChanceBonus == 0)
    }

    @Test func serratedEdgeHasNoCriticalBonus() throws {
        try #expect(Ability.serratedEdge.summary == "Deal 3 Bleed damage.")
        try #expect(Ability.serratedEdge.criticalChanceBonus == 0)
    }

    @Test func stabDealsTwoPhysicalDamage() throws {
        try #expect(Ability.stab.summary == "Deal 2 Physical damage.")
        try #expect(Ability.stab.directDamage == 2)
    }

    @Test func bloodOfferingAndDarkPactSummaries() throws {
        try #expect(Ability.bloodOffering.summary == "Lose 2 Health. Deal 4 Bleed damage.")
        try #expect(Ability.darkPact.summary == "Lose 2 Health. Draw 2 cards.")
        try #expect(!Ability.bloodOffering.hasLeech)
        try #expect(!Ability.darkPact.hasLeech)
    }

    @Test func gravePactIsRemovedFromCatalog() throws {
        try #expect(AbilityCatalog.all.contains { $0.id == "grave-pact" } == false)
    }

    @Test func abilityHealHasNoDamage() throws {
        try #expect(Ability.heal.summary == "Costs 1 Mana, restore 3 Health.")
        try #expect(Ability.heal.directDamage == 0)
    }

    @Test func descriptionOverridesAreAllowlisted() throws {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            try #expect(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override"
            )
        }
    }

    @Test(arguments: AbilityCatalog.all)
    func abilityLookupByID(ability: Ability) throws {
        try #expect(AbilityCatalog.ability(id: ability.id) == ability)
    }
}
