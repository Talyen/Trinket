import Testing
@testable import TrinketContent

@Suite
struct ArtCatalogIntegrationTests {
    /// Abilities intentionally shipping without curated art yet (cinematic / placeholder path).
    private static let abilitiesAllowedWithoutArt: Set<String> = [
        "avatar-of-justice"
    ]

    @Test func everyCatalogAbilityHasArt() throws {
        for ability in AbilityCatalog.all {
            if Self.abilitiesAllowedWithoutArt.contains(ability.id) {
                continue
            }
            _ = try #require(
                ability.artReference,
                "Missing art for ability id \(ability.id)"
            )
        }
    }

    @Test func artCatalogOnlyReferencesKnownAbilities() throws {
        let catalogIDs = Set(AbilityCatalog.all.map(\.id))
        let artIDs = Set(ArtCatalog.abilityArtByID.keys)
        let unknownArtIDs = artIDs.subtracting(catalogIDs)
        try #expect(
            unknownArtIDs.isEmpty,
            "Art catalog references unknown ability IDs: \(unknownArtIDs.sorted())"
        )
    }

    @Test func gameContentReferencesResolveInCatalog() throws {
        let referenced = referencedAbilityIDs()
        for id in referenced {
            _ = try #require(
                AbilityCatalog.ability(id: id),
                "GameContent references unknown ability id \(id)"
            )
        }
    }

    @Test func eachHeroAndPetHasArtReference() throws {
        for hero in GameContent.heroes {
            _ = try #require(
                ArtCatalog.combatantArtByID[hero.id],
                "\(hero.name) should have an art reference in the catalog"
            )
        }

        for pet in GameContent.pets {
            _ = try #require(
                ArtCatalog.combatantArtByID[pet.id],
                "\(pet.name) should have an art reference in the catalog"
            )
        }
    }

    @Test func eachEnemyHasArtReference() throws {
        for enemy in GameContent.enemies {
            _ = try #require(
                ArtCatalog.combatantArtByID[enemy.id],
                "\(enemy.name) should have an art reference in the catalog"
            )
        }
    }

    @Test func encounterArtReferencesExistInCatalog() throws {
        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                guard let artID = GameContent.encounterArtID(for: stage) else { continue }
                _ = try #require(
                    ArtCatalog.encounterArtByID[artID],
                    "Stage \(stage.id) references missing encounter art \(artID)"
                )
            }
        }
    }

    @Test func sampleInventoryItemsHaveArtReference() throws {
        for item in GameContent.sampleInventoryItems {
            _ = try #require(
                item.artReference,
                "Missing art for inventory template \(item.templateID)"
            )
        }
    }

    @Test func rewardInstanceItemsKeepArtReference() throws {
        let template = try #require(GameContent.sampleInventoryItems.first)
        let rewarded = template.rewardInstance(for: "chapter-1-stage-1")
        #expect(rewarded.id != rewarded.templateID)
        _ = try #require(
            rewarded.artReference,
            "Missing art after rewardInstance for \(rewarded.templateID)"
        )
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
