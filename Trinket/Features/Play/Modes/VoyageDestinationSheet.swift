import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct VoyageDestinationSelection: Hashable, Identifiable {
    let id: String
    let chapterID: String
}

struct VoyageDestinationSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.locale) private var locale
    let offer: VoyageOffer
    @State private var requestedEnemy: CombatantCardDetail?
    @State private var inspectedEnemy: CombatantCardDetail?

    private var enemies: [Enemy] {
        let ids = VoyageCatalog.enemyIDs(chapterID: offer.chapterID)
            + [VoyageCatalog.bossID(chapterID: offer.chapterID)].compactMap(\.self)
        return ids.compactMap { GameContent.enemy(matching: $0) }
    }

    private var level: Int {
        EncounterScaling.voyage(offer.difficulty).resolve(partyAverageLevel: playerSave.roster.activePartyAverageLevel).level
    }

    private var reward: ModifierCaptionPresentation {
        ModifierCaptionPresentation(offer.rewardModifier.resolved(
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
        ))
    }

    static func artworkNames(chapterID: String) -> [String] {
        let ids = VoyageCatalog.enemyIDs(chapterID: chapterID) + [VoyageCatalog.bossID(chapterID: chapterID)].compactMap(\.self)
        let enemyArt = ids.compactMap { GameContent.enemy(matching: $0)?.combatant.artReference }
        return [ArtCatalog.backgroundArtByID[chapterID]?.imageName].compactMap(\.self)
            + enemyArt.map { $0.preparedThumbnailImageName ?? $0.imageName }
    }

    var body: some View {
        NavigationStack {
            DetailHeroScrollShell(
                title: GameContent.chapter(id: offer.chapterID)?.title ?? "", heroHeightPolicy: .cinematicLandscape,
            ) { height in
                DetailHeroHeader(
                    eyebrow: offer.difficulty.title,
                    title: GameContent.chapter(id: offer.chapterID)?.title ?? "",
                    baseHeight: height,
                ) {
                    if let art = ArtCatalog.backgroundArtByID[offer.chapterID] {
                        FocalBackgroundArtwork(art: art)
                    }
                } footer: {
                    StageSelectModifierLine(modifier: reward)
                }
            } bodyContent: {
                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                    Text(L10n.voyage_destination_enemies)
                        .trinketTypography(.sectionTitle)
                        .accessibilityIdentifier(AccessibilityID.Voyage.destinationSheet)
                    ForEach(enemies) { enemy in
                        Button {
                            requestedEnemy = makePlayEnemyDetail(combatant: enemy.combatant, level: level)
                        } label: {
                            CombatantArtwork(combatant: enemy.combatant, variant: .card)
                                .aspectRatio(1200.0 / 896, contentMode: .fit)
                                .clipShape(TrinketDesign.cardShape)
                        }
                        .trinketArtworkCardButtonStyle()
                        .accessibilityLabel(ContentCopy.localized(enemy.name, locale: locale))
                        .accessibilityIdentifier(AccessibilityID.Voyage.destinationEnemy(enemy.id))
                    }
                }
                .padding(TrinketDesign.Layout.contentMargin)
            }
            .navigationDestination(item: $inspectedEnemy) { detail in
                CombatantDetailPane(snapshot: detail)
            }
            .preparingArtwork(request: $requestedEnemy, presentation: $inspectedEnemy) { detail in
                CombatantDetailPane.artworkNames(
                    combatant: detail.combatant, loadout: detail.combatant.abilityLoadout,
                    equipmentLoadout: detail.equipmentLoadout, inventoryItems: detail.inventoryItems,
                )
            }
        }
    }
}
