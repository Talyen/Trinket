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

    func testDoTPairingMatchesDirectDamage() {
        for ability in AbilityCatalog.all {
            guard ability.directDamage > 0 else { continue }
            switch ability.damageKeyword {
            case .burn:
                XCTAssertTrue(
                    ability.effects.contains {
                        if case let .burn(potency) = $0 { return potency == ability.directDamage }
                        return false
                    },
                    "\(ability.id) should pair Burn direct damage with .burn(\(ability.directDamage))"
                )
            case .poison:
                XCTAssertTrue(
                    ability.effects.contains {
                        if case let .poison(potency) = $0 { return potency == ability.directDamage }
                        return false
                    },
                    "\(ability.id) should pair Poison direct damage with .poison(\(ability.directDamage))"
                )
            case .bleed:
                XCTAssertTrue(
                    ability.effects.contains {
                        if case let .bleed(potency) = $0 { return potency == ability.directDamage }
                        return false
                    },
                    "\(ability.id) should pair Bleed direct damage with .bleed(\(ability.directDamage))"
                )
            default:
                continue
            }
        }
    }

    func testDescriptionsAreNonEmpty() {
        for ability in AbilityCatalog.all {
            XCTAssertFalse(ability.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertEqual(ability.summary, ability.description)
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
