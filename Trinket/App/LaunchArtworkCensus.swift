import TrinketAppState
import TrinketContent
import TrinketCore
import TrinketDesignSystem

@MainActor
enum LaunchArtworkCensus {
    static func priorityImageNames(for appState: AppState) -> [String] {
        let activeParty = [appState.playerSave.roster.activeHero, appState.playerSave.roster.activeCompanion]
            .compactMap(\.artReference)
            .flatMap { reference in
                [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
            }
        let starterChoices: [String] =
            if appState.playerSave.starterSelection.phase == .complete {
                []
            } else {
                GameContent.combatants
                    .compactMap { $0.artReference?.thumbnailImageName }
            }
        let activeEnemy = appState.playerSave.journey.activeStageID
            .flatMap(GameContent.stage(id:))?
            .encounterCombatantArtReference(worldSeed: appState.playerSave.worldSeed)
        let enemyNames = activeEnemy.map { reference in
            [reference.imageName, reference.thumbnailImageName].compactMap(\.self)
        } ?? []
        return Array(
            Set(activeParty + starterChoices + enemyNames + rootTabImageNames(for: appState)),
        ).sorted()
    }

    private static func rootTabImageNames(for appState: AppState) -> [String] {
        let roster = appState.playerSave.roster
        let inventory = appState.playerSave.inventory
        let shelfLimit = TrinketDesign.Layout.collectionShelfPreviewLimit

        let collectionCombatants = (
            Array(roster.collectionHeroes.prefix(shelfLimit))
                + Array(roster.collectionCompanions.prefix(shelfLimit)),
        ).compactMap { $0.artReference?.thumbnailImageName }
        let collectionDetail = CollectionView.imminentDetailArtworkNames(roster: roster)
        let collectionItems = CollectionItemCategory.allCases.flatMap { category in
            category.collectionItems(in: inventory.items).prefix(shelfLimit).compactMap {
                $0.artReference?.thumbnailImageName
            }
        }
        let playModeCards = ["gameModeCampaign", "gameModeExplore"].compactMap {
            ArtCatalog.backgroundArtByID[$0]?.imageName
        }
        let homesteadCards = HomesteadNodeCategory.allCases.compactMap {
            ArtCatalog.backgroundArtByID[$0.artID]?.imageName
        }
        let homesteadGalleryThumbnails = ArtCatalog.portraitBackgroundArtByID.values.compactMap(\.thumbnailImageName)
        let homesteadHero = ArtCatalog.backgroundArtByID["homestead"]?.imageName
        let resourceIcons = ArtCatalog.resourceArtByID.values.map(\.imageName)

        let chapter = appState.play.journey.playChapter
        let campaignHero = (
            ArtCatalog.backgroundArtByID[chapter.id]
                ?? ArtCatalog.backgroundArtByID["chapter-1"],
        )?.imageName
        let campaignRows = chapter.stages.flatMap { stage -> [String] in
            if let combatant = stage.encounterCombatantArtReference(
                worldSeed: appState.playerSave.worldSeed,
            ) {
                return [combatant.imageName, combatant.thumbnailImageName].compactMap(\.self)
            }
            if let encounter = stage.encounterArtReference {
                return [encounter.imageName, encounter.thumbnailImageName].compactMap(\.self)
            }
            return []
        }

        return collectionCombatants
            + collectionDetail
            + collectionItems
            + playModeCards
            + homesteadCards
            + homesteadGalleryThumbnails
            + resourceIcons
            + campaignRows
            + [homesteadHero, campaignHero].compactMap(\.self)
    }
}
