import XCTest
import TrinketCore
import TrinketContent

final class AbilityCatalogTests: XCTestCase {
    func testCatalogIDsAreUnique() {
        let ids = AbilityCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)")
    }

    func testUnknownAbilityLookupReturnsNil() {
        XCTAssertNil(AbilityCatalog.ability(id: "missing-ability"))
    }

    func testStaticReexportsMatchCatalog() {
        XCTAssertEqual(Ability.fireball, AbilityCatalog.ability(id: Ability.fireball.id))
        XCTAssertEqual(Ability.bloodthorn, AbilityCatalog.ability(id: Ability.bloodthorn.id))
        XCTAssertEqual(Ability.slash, AbilityCatalog.ability(id: Ability.slash.id))
    }

    func testDoTPairingMatchesDamageComponents() {
        for ability in AbilityCatalog.all {
            if ["mana-berries", "pixie-dust"].contains(ability.id) {
                continue
            }
            for component in ability.damageComponents where component.target == .abilityTarget {
                switch component.keyword {
                case .burn:
                    XCTAssertTrue(
                        ability.effects.contains {
                            if case let .burn(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Burn damage with .burn(\(component.amount))"
                    )
                case .poison:
                    XCTAssertTrue(
                        ability.effects.contains {
                            if case let .poison(potency) = $0 { return potency == component.amount }
                            return false
                        },
                        "\(ability.id) should pair Poison damage with .poison(\(component.amount))"
                    )
                case .bleed:
                    XCTAssertTrue(
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

    func testBloodthornUsesDamageComponents() {
        XCTAssertEqual(Ability.bloodthorn.damageComponents.count, 3)
        XCTAssertEqual(Ability.bloodthorn.directDamage, 6)
        XCTAssertEqual(Ability.fireball.directDamage, 2)
        XCTAssertEqual(Ability.fireball.damageKeyword, .burn)
    }

    func testCatalogPassesValidation() {
        let issues = AbilityValidator.validateCatalog()
        XCTAssertTrue(issues.isEmpty, issues.map(\.description).joined(separator: "\n"))
    }

    func testAbilityBuilderMatchesDirectHitPattern() {
        let built = AbilityBuilder.directHit(
            id: "fireball",
            name: "Fireball",
            tier: .skill,
            amount: 2,
            keyword: .burn
        )
        XCTAssertEqual(built.damageComponents, Ability.fireball.damageComponents)
        XCTAssertEqual(built.targetedEffects, Ability.fireball.targetedEffects)
        XCTAssertEqual(built.summary, Ability.fireball.summary)
    }

    func testDirectHitBuilderAddsPairedDoT() {
        let ability = AbilityBuilder.directHit(
            id: "burn-hit",
            name: "Burn Hit",
            tier: .skill,
            amount: 3,
            keyword: .burn
        )
        XCTAssertEqual(ability.damageComponents, [DamageComponent(3, keyword: .burn)])
        XCTAssertTrue(ability.effects.contains { if case .burn(3) = $0 { return true }; return false })
        XCTAssertEqual(ability.summary, "Deal 3 Burn damage and applies Burning.")
    }

    func testBuffOnlyBuilderProducesGeneratedDescription() {
        let ability = AbilityBuilder.buffOnly(
            id: "block",
            name: "Block",
            tier: .basic,
            effects: [.shield(.block, 2, 6)]
        )
        XCTAssertEqual(ability.summary, "Gain Block.")
    }

    func testMultiDamageBuilderFormatsSummary() {
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
        XCTAssertEqual(
            ability.summary,
            "Deal 2 Nature damage, Deal 2 Bleed damage and applies Bleeding, Deal 2 Poison damage and applies Poisoned and Gain Leech."
        )
    }

    func testAbilityUsesGeneratedDescription() {
        let ability = Ability.rayOfFrost
        XCTAssertEqual(ability.summary, "Deal 1 Freeze damage.")
    }

    func testAbilityHealHasNoDamage() {
        XCTAssertEqual(Ability.heal.summary, "Costs 1 Mana, restore 3 Health.")
        XCTAssertEqual(Ability.heal.directDamage, 0)
    }

    func testDescriptionOverridesAreAllowlisted() {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            XCTAssertTrue(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override"
            )
        }
    }
}
