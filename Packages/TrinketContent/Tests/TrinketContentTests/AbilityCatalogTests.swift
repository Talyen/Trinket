import Testing
import TrinketCore
import TrinketContent

@Suite
struct AbilityCatalogTests {
    @Test func catalogIDsAreUnique() {
        let ids = AbilityCatalog.all.map(\.id)
        #expect(Set(ids).count == ids.count, "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)")
    }

    @Test func unknownAbilityLookupReturnsNil() {
        #expect(AbilityCatalog.ability(id: "missing-ability") == nil)
    }

    @Test func staticReexportsMatchCatalog() {
        #expect(Ability.fireball == AbilityCatalog.ability(id: Ability.fireball.id))
        #expect(Ability.bloodthorn == AbilityCatalog.ability(id: Ability.bloodthorn.id))
        #expect(Ability.slash == AbilityCatalog.ability(id: Ability.slash.id))
    }

    @Test func doTPairingMatchesDamageComponents() {
        for ability in AbilityCatalog.all {
            if ["mana-berries", "pixie-dust"].contains(ability.id) {
                continue
            }
            for component in ability.damageComponents where component.target == .abilityTarget {
                switch component.keyword {
                case .burn:
                    #expect(
                        ability.effects.contains {
                            if case let .burn(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Burn damage with .burn(\(component.amount))"
                    )
                case .poison:
                    #expect(
                        ability.effects.contains {
                            if case let .poison(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Poison damage with .poison(\(component.amount))"
                    )
                case .bleed:
                    #expect(
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

    @Test func bloodthornUsesDamageComponents() {
        #expect(Ability.bloodthorn.damageComponents.count == 3)
        #expect(Ability.bloodthorn.directDamage == 6)
        #expect(Ability.fireball.directDamage == 2)
        #expect(Ability.fireball.damageKeyword == .burn)
    }

    @Test func catalogPassesValidation() {
        let issues = AbilityValidator.validateCatalog()
        #expect(issues.isEmpty, issues.map(\.description).joined(separator: "\n"))
    }

    @Test func abilityBuilderMatchesDirectHitPattern() {
        let built = AbilityBuilder.directHit(
            id: "fireball",
            name: "Fireball",
            tier: .skill,
            amount: 2,
            keyword: .burn
        )
        #expect(built.damageComponents == Ability.fireball.damageComponents)
        #expect(built.targetedEffects == Ability.fireball.targetedEffects)
        #expect(built.summary == Ability.fireball.summary)
    }

    @Test func directHitBuilderAddsPairedDoT() {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn
        )
        #expect(ability.damageComponents == [DamageComponent(3, keyword: .burn)])
        #expect(ability.effects.contains { if case .burn(3) = $0 { return true }; return false })
        #expect(ability.summary == "Deal 3 Burn damage and applies Burning.")
    }

    @Test func buffOnlyBuilderProducesGeneratedDescription() {
        let ability = AbilityBuilder.buffOnly(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2, 6)]
        )
        #expect(ability.summary == "Gain Block.")
    }

    @Test func multiDamageBuilderFormatsSummary() {
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
                TargetedEffect(.poison(2)),
                TargetedEffect(.standardLeechBuff)
            ]
        )
        #expect(
            ability.summary == "Deal 2 Nature damage, Deal 2 Bleed damage and applies Bleeding, Deal 2 Poison damage and applies Poisoned and Gain Leech."
        )
    }

    @Test func abilityUsesGeneratedDescription() {
        let ability = Ability.rayOfFrost
        #expect(ability.summary == "Deal 1 Freeze damage.")
    }

    @Test func abilityHealHasNoDamage() {
        #expect(Ability.heal.summary == "Costs 1 Mana, restore 3 Health.")
        #expect(Ability.heal.directDamage == 0)
    }

    @Test func descriptionOverridesAreAllowlisted() {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            #expect(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override"
            )
        }
    }

    @Test(arguments: AbilityCatalog.all)
    func abilityLookupByID(ability: Ability) {
        #expect(AbilityCatalog.ability(id: ability.id) == ability)
    }
}
