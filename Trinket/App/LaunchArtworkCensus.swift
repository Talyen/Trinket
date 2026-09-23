import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

@MainActor
enum LaunchArtworkCensus {
    static func priorityImageNames(
        for save: PlayerSave,
        contentAccess: ContentAccessPolicy,
        previewMysteryEvent: (Stage) -> MysteryEvent?,
    ) -> [String] {
        var names = Set<String>()

        for combatant in [save.roster.activeHero, save.roster.activeCompanion] {
            if let ref = combatant.artReference {
                names.insert(ref.imageName)
                if let thumb = ref.thumbnailImageName {
                    names.insert(thumb)
                }
            }
        }

        if save.starterSelection.phase != .complete {
            for combatant in GameContent.combatants {
                if let thumb = combatant.artReference?.thumbnailImageName {
                    names.insert(thumb)
                }
            }
        }

        if let stageID = save.journey.activeStageID,
           let stage = GameContent.stage(id: stageID),
           let enemyRef = stage.encounterCombatantArtReference(worldSeed: save.worldSeed) {
            names.insert(enemyRef.imageName)
            if let thumb = enemyRef.thumbnailImageName {
                names.insert(thumb)
            }
        }

        if let art = ArtCatalog.backgroundArtByID["gameModeVoyage"] {
            names.insert(art.imageName)
            if let thumbnail = art.thumbnailImageName {
                names.insert(thumbnail)
            }
        }
        collectRootTabImageNames(
            into: &names, for: save, contentAccess: contentAccess,
            previewMysteryEvent: previewMysteryEvent,
        )
        return names.sorted()
    }

    private static func collectRootTabImageNames(
        into names: inout Set<String>,
        for save: PlayerSave,
        contentAccess: ContentAccessPolicy,
        previewMysteryEvent: (Stage) -> MysteryEvent?,
    ) {
        collectCollectionImageNames(into: &names, for: save)
        collectHomesteadAndResourceImageNames(into: &names)
        collectCampaignImageNames(
            into: &names, for: save, contentAccess: contentAccess,
            previewMysteryEvent: previewMysteryEvent,
        )
    }

    private static func collectCollectionImageNames(into names: inout Set<String>, for save: PlayerSave) {
        let roster = save.roster
        let inventory = save.inventory
        let shelfLimit = TrinketDesign.Layout.collectionShelfPreviewLimit

        for hero in roster.collectionHeroes.prefix(shelfLimit) {
            if let thumb = hero.artReference?.thumbnailImageName {
                names.insert(thumb)
            }
        }
        for companion in roster.collectionCompanions.prefix(shelfLimit) {
            if let thumb = companion.artReference?.thumbnailImageName {
                names.insert(thumb)
            }
        }
        names.formUnion(CollectionView.imminentDetailArtworkNames(roster: roster))

        for category in CollectionItemCategory.allCases {
            for item in category.collectionItems(in: inventory.items).prefix(shelfLimit) {
                if let thumb = item.artReference?.thumbnailImageName {
                    names.insert(thumb)
                }
            }
        }
    }

    private static func collectHomesteadAndResourceImageNames(into names: inout Set<String>) {
        for id in [EncounterArtIDs.campaignPlayModeID, EncounterArtIDs.explorePlayModeID] {
            if let img = ArtCatalog.backgroundArtByID[id]?.imageName {
                names.insert(img)
            }
        }

        for category in HomesteadNodeCategory.allCases {
            if let img = ArtCatalog.backgroundArtByID[category.artID]?.imageName {
                names.insert(img)
            }
        }

        for portrait in ArtCatalog.portraitBackgroundArtByID.values {
            if let thumb = portrait.thumbnailImageName {
                names.insert(thumb)
            }
        }

        if let hero = ArtCatalog.backgroundArtByID[EncounterArtIDs.homesteadHeroID]?.imageName {
            names.insert(hero)
        }

        for resource in ArtCatalog.resourceArtByID.values {
            names.insert(resource.imageName)
        }
    }

    private static func collectCampaignImageNames(
        into names: inout Set<String>,
        for save: PlayerSave,
        contentAccess: ContentAccessPolicy,
        previewMysteryEvent: (Stage) -> MysteryEvent?,
    ) {
        let baseChapter = GameContent.chapter(id: save.journey.activeChapterID) ?? GameContent.chapters[0]
        let chapter = CampaignStagePresentation.chapter(baseChapter, save: save, contentAccess: contentAccess)
        if let chapterImg = (ArtCatalog.backgroundArtByID[chapter.id]
            ?? ArtCatalog.backgroundArtByID[EncounterArtIDs.fallbackChapterID])?.imageName {
            names.insert(chapterImg)
        }

        for stage in chapter.stages {
            if let art = EncounterArtwork.reference(
                for: stage,
                resolvedMysteryEvent: previewMysteryEvent(stage),
                worldSeed: save.worldSeed,
            ) {
                names.insert(art.imageName)
                if let thumb = art.preparedThumbnailImageName {
                    names.insert(thumb)
                }
            }
        }
    }
}
