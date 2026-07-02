import XCTest
@testable import Trinket

final class AbilityCatalogTests: XCTestCase {
    func testCatalogHasExpectedAbilityCount() {
        XCTAssertEqual(AbilityCatalog.all.count, 76)
    }

    func testCatalogIDsAreUnique() {
        let ids = AbilityCatalog.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "Duplicate ability IDs: \(Dictionary(grouping: ids, by: { $0 }).filter { $1.count > 1 }.keys)")
    }

    func testAbilityLookupByID() {
        for ability in AbilityCatalog.all {
            XCTAssertEqual(AbilityCatalog.ability(id: ability.id), ability)
        }
        XCTAssertNil(AbilityCatalog.ability(id: "missing-ability"))
    }

    func testStaticReexportsMatchCatalog() {
        XCTAssertEqual(Ability.fireball, AbilityCatalog.fireball)
        XCTAssertEqual(Ability.bloodthorn, AbilityCatalog.bloodthorn)
        XCTAssertEqual(Ability.slash, AbilityCatalog.slash)
    }

    func testEveryCatalogAbilityHasArt() {
        for ability in AbilityCatalog.all {
            XCTAssertNotNil(
                ability.artReference,
                "Missing art for ability id \(ability.id)"
            )
        }
    }

    func testArtCatalogOnlyReferencesKnownAbilities() {
        let catalogIDs = Set(AbilityCatalog.all.map(\.id))
        let artIDs = Set(ArtCatalog.abilityArtByID.keys)
        let unknownArtIDs = artIDs.subtracting(catalogIDs)
        XCTAssertTrue(
            unknownArtIDs.isEmpty,
            "Art catalog references unknown ability IDs: \(unknownArtIDs.sorted())"
        )
    }

    func testGameContentReferencesResolveInCatalog() {
        let referenced = referencedAbilityIDs()
        for id in referenced {
            XCTAssertNotNil(
                AbilityCatalog.ability(id: id),
                "GameContent references unknown ability id \(id)"
            )
        }
    }

    func testDoTPairingMatchesDamageComponents() {
        for ability in AbilityCatalog.all {
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
        XCTAssertEqual(Ability.fireball.directDamage, 3)
        XCTAssertEqual(Ability.fireball.damageKeyword, .burn)
    }

    func testCatalogDoesNotUseDealDamageEffects() {
        for ability in AbilityCatalog.all {
            XCTAssertFalse(
                ability.effects.contains {
                    if case .dealDamage = $0 { return true }
                    return false
                },
                "\(ability.id) should express damage through damageComponents, not dealDamage effects"
            )
        }
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
            amount: 3,
            keyword: .burn
        )
        XCTAssertEqual(built.damageComponents, Ability.fireball.damageComponents)
        XCTAssertEqual(built.targetedEffects, Ability.fireball.targetedEffects)
        XCTAssertEqual(built.summary, Ability.fireball.summary)
    }

    func testSummariesAreNonEmpty() {
        for ability in AbilityCatalog.all {
            XCTAssertFalse(ability.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testDescriptionOverridesAreAllowlisted() {
        for ability in AbilityCatalog.all where ability.descriptionOverride != nil {
            XCTAssertTrue(
                AbilityValidator.descriptionOverrideIDs.contains(ability.id),
                "\(ability.id) should not carry a manual description override"
            )
        }
    }

    private func referencedAbilityIDs() -> Set<String> {
        var ids = Set<String>()
        let combatants = GameContent.heroes + GameContent.pets + GameContent.enemies.map(\.combatant)
        for combatant in combatants {
            for ability in combatant.abilityChoices.basics + combatant.abilityChoices.skills + combatant.abilityChoices.ultimates {
                ids.insert(ability.id)
            }
            for ability in combatant.abilityLoadout.abilities {
                ids.insert(ability.id)
            }
        }
        return ids
    }
}
