import Testing
import TrinketCore
@testable import TrinketContent

struct ArtCatalogIntegrationTests {
    // This cross-catalog invariant intentionally owns all art-reference domains.
    // swiftlint:disable function_body_length
    @Test func catalogAndContentArtReferencesResolveAcrossAllDomains() throws {
        for ability in AbilityCatalog.all {
            _ = try #require(
                ability.artReference,
                "Missing art for ability id \(ability.id)"
            )
        }

        let catalogIDs = Set(AbilityCatalog.all.map(\.id))
        let artIDs = Set(ArtCatalog.abilityArtByID.keys)
        let unknownArtIDs = artIDs.subtracting(catalogIDs)
        try #expect(
            unknownArtIDs.isEmpty,
            "Art catalog references unknown ability IDs: \(unknownArtIDs.sorted())"
        )

        let referenced = referencedAbilityIDs()
        for id in referenced {
            _ = try #require(
                AbilityCatalog.ability(id: id),
                "GameContent references unknown ability id \(id)"
            )
        }

        for hero in GameContent.heroes {
            _ = try #require(
                ArtCatalog.combatantArtByID[hero.id],
                "\(hero.name) should have an art reference in the catalog"
            )
        }

        for companion in GameContent.companions {
            _ = try #require(
                ArtCatalog.combatantArtByID[companion.id],
                "\(companion.name) should have an art reference in the catalog"
            )
        }

        for enemy in GameContent.enemies {
            _ = try #require(
                ArtCatalog.combatantArtByID[enemy.id],
                "\(enemy.name) should have an art reference in the catalog"
            )
        }

        for chapter in GameContent.chapters {
            for stage in chapter.stages {
                guard let artID = GameContent.encounterArtID(for: stage) else { continue }
                _ = try #require(
                    ArtCatalog.encounterArtByID[artID],
                    "Stage \(stage.id) references missing encounter art \(artID)"
                )
                try #expect(
                    !(GameContent.encounterArtTitle(for: stage)?.isEmpty ?? true),
                    "Encounter art title should be set when art id is set for \(stage.id)"
                )
            }
        }

        for item in GameContent.sampleInventoryItems {
            _ = try #require(
                item.artReference,
                "Missing art for inventory template \(item.templateID)"
            )
        }

        for baseType in GameContent.itemBaseTypes {
            _ = try #require(
                baseType.previewArtReference,
                "Missing base preview art for item base \(baseType.id)"
            )
        }

        let template = try #require(GameContent.sampleInventoryItems.first)
        let rewarded = template.rewardInstance(for: "chapter-1-stage-1")
        #expect(rewarded.id != rewarded.templateID)
        _ = try #require(
            rewarded.artReference,
            "Missing art after rewardInstance for \(rewarded.templateID)"
        )

        for resource in HomesteadResource.allCases {
            _ = try #require(
                ArtCatalog.resourceArtByID[resource.rawValue],
                "Missing Homestead resource art for \(resource.rawValue)"
            )
        }
    }

    // swiftlint:enable function_body_length

    @Test func backgroundFocalPointsAreNormalized() {
        for art in ArtCatalog.backgroundArtByID.values {
            #expect((0 ... 1).contains(art.focalPoint.x))
            #expect((0 ... 1).contains(art.focalPoint.y))
        }
    }

    private func referencedAbilityIDs() -> Set<String> {
        var ids = Set<String>()
        let combatants = GameContent.heroes + GameContent.companions + GameContent.enemies.map(\.combatant)
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
