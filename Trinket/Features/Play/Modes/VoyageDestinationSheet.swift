import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureSupport
import TrinketPersistence

struct VoyageDestinationSelection: Hashable, Identifiable {
    let id: String
}

struct VoyageDestinationSheet: View {
    @Environment(PlayerSaveStore.self) private var playerSave
    let offer: VoyageOffer
    @State private var requestedEnemy: CombatantCardDetail?
    @State private var inspectedEnemy: CombatantCardDetail?

    private var level: Int {
        EncounterScaling.voyage(offer.difficulty).resolve(partyAverageLevel: playerSave.roster.activePartyAverageLevel).level
    }

    private var reward: ModifierCaptionPresentation {
        ModifierCaptionPresentation(offer.rewardModifier.resolved(
            ownedTrinketIDs: playerSave.inventory.ownedTrinketIDs,
            ownedUniqueIDs: playerSave.inventory.ownedUniqueIDs,
        ))
    }

    private static func preview(offer: VoyageOffer, save: PlayerSave, access: ContentAccessPolicy) -> (VoyageRun, PlayerSave) {
        let nodes = VoyageGenerator.nodes(
            for: offer,
            eligibleRecruitEventIDs: save.roster.eligibleRecruitEventIDs(access: access),
            eligibleRewards: RewardOwnership(save).eligibleModifiers,
        )
        let run = VoyageRun(offer: offer, nodes: nodes)
        var previewSave = save
        previewSave.voyage.activeRun = run
        return (run, previewSave)
    }

    private static func artwork(
        for node: VoyageNode, in run: VoyageRun, save: PlayerSave, access: ContentAccessPolicy,
    ) -> (any PreparedArtworkReference)? {
        if let enemyID = node.enemyID {
            return GameContent.enemy(matching: enemyID)?.combatant.artReference
        }
        if node.type == .recruit {
            return GameContent.recruitEncounterArtReference(forEventID: node.recruitEventID)
        }
        if node.type == .mystery,
           let event = EncounterIdentity(location: .voyage(runID: run.id, nodeID: node.id), save: save)
           .mysteryEvent(in: save, access: access) {
            return MysteryEventArtwork.preparedReference(event: event, chapterID: run.offer.chapterID)
        }
        return LabyrinthMapPresentation.destinationEncounterArtID(for: node.type).flatMap { ArtCatalog.encounterArtByID[$0] }
    }

    static func artworkNames(offer: VoyageOffer, save: PlayerSave, access: ContentAccessPolicy) -> [String] {
        let (run, previewSave) = preview(offer: offer, save: save, access: access)
        let artworkNames = run.nodes.compactMap { artwork(for: $0, in: run, save: previewSave, access: access) }
            .map { $0.preparedThumbnailImageName ?? $0.imageName }
        return [ArtCatalog.backgroundArtByID[offer.chapterID]?.imageName].compactMap(\.self) + artworkNames
    }

    private func inspect(_ node: VoyageNode) {
        guard let enemy = node.enemyID.flatMap({ GameContent.enemy(matching: $0) }) else { return }
        let modifiers = RewardOwnership(playerSave.inventory).modifiers(ids: node.modifierIDs, enemyIsBoss: node.type == .boss)
        requestedEnemy = makePlayEnemyDetail(combatant: enemy.combatant, level: level, nodeModifiers: modifiers)
    }

    var body: some View {
        let (run, previewSave) = Self.preview(offer: offer, save: playerSave.currentSave, access: playerSave.contentAccess)
        return NavigationStack {
            DetailHeroScrollShell(
                title: GameContent.chapter(id: offer.chapterID)?.title ?? "", heroHeightPolicy: .cinematicLandscape,
            ) { height in
                DetailHeroHeader(
                    eyebrow: offer.difficulty.title,
                    title: GameContent.chapter(id: offer.chapterID)?.title ?? "",
                    titleAccessibilityIdentifier: AccessibilityID.Voyage.destinationSheet,
                    baseHeight: height,
                    footerSpacing: TrinketDesign.Spacing.tight,
                ) {
                    if let art = ArtCatalog.backgroundArtByID[offer.chapterID] {
                        FocalBackgroundArtwork(art: art)
                    }
                } footer: {
                    StageSelectModifierLine(modifier: reward)
                }
            } bodyContent: {
                StageSelectList(
                    rows: StageSelectRowPresentation<VoyageNode>.voyageNodes(run, inventory: playerSave.inventory, allCompact: true),
                    isPrimaryActionDisabled: { _ in true }, onArtworkTap: inspect,
                    onPrimaryAction: { _ in false }, artwork: { node, _ in
                        if let art = Self.artwork(for: node, in: run, save: previewSave, access: playerSave.contentAccess) {
                            MapTileArtwork(art: art, prefersThumbnail: true)
                        } else {
                            MapTilePlaceholder(tint: LabyrinthMapPresentation.tint(for: node.type), icon: GameIcon(id: node.type.iconID))
                        }
                    }, partyPickerSheet: { _ in EmptyView() },
                )
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
