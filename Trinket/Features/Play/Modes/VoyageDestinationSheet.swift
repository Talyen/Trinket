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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    let offer: VoyageOffer
    let isEmbarkDisabled: Bool
    let onEmbark: () -> Bool
    @State private var inspectedEnemy: CombatantCardDetail?

    private var level: Int {
        EncounterScaling.voyage(offer.difficulty).resolve(partyAverageLevel: playerSave.roster.activePartyAverageLevel).level
    }

    private var enemies: [Enemy] {
        VoyageCatalog.enemyIDs(chapterID: offer.chapterID).compactMap { GameContent.enemy(matching: $0) }
    }

    private var boss: Enemy? {
        VoyageCatalog.bossID(chapterID: offer.chapterID).flatMap { GameContent.enemy(matching: $0) }
    }

    private var route: [VoyageNode] {
        VoyageGenerator.nodes(
            for: offer,
            eligibleRecruitEventIDs: playerSave.roster.eligibleRecruitEventIDs(access: playerSave.contentAccess),
        )
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
                    Text(L10n.voyage_destination_level("\(level)"))
                        .trinketOnArtText(.eyebrow)
                }
            } bodyContent: {
                VStack(alignment: .leading, spacing: TrinketDesign.Spacing.large) {
                    enemySection
                    if let boss {
                        bossSection(boss)
                    }
                    routeSection
                    completionSection
                }
                .padding(TrinketDesign.Layout.contentMargin)
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    if onEmbark() {
                        dismiss()
                    }
                } label: {
                    Text(L10n.voyage_destination_embark)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton(
                    tint: TrinketDesign.Colors.accent, accessibilityIdentifier: AccessibilityID.Voyage.destinationEmbark,
                )
                .disabled(isEmbarkDisabled || playerSave.isRetryingSaveAction)
                .padding(TrinketDesign.Layout.contentMargin)
                .trinketScreenBackground()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel(Text(L10n.ui_fullgameofferview_close_7d9eb))
                        .accessibilityIdentifier(AccessibilityID.Voyage.destinationClose)
                }
            }
        }
        .modifier(CombatantDetailSheet(
            selection: $inspectedEnemy,
            artworkNames: { detail in
                CombatantDetailPane.artworkNames(
                    combatant: detail.combatant, loadout: detail.combatant.abilityLoadout,
                    equipmentLoadout: detail.equipmentLoadout, inventoryItems: detail.inventoryItems,
                )
            },
            detailContent: { detail in CombatantDetailPane(snapshot: detail) },
        ))
    }

    private var enemySection: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Text(L10n.voyage_destination_enemies)
                .trinketTypography(.sectionTitle)
                .accessibilityIdentifier(AccessibilityID.Voyage.destinationSheet)
            LazyVGrid(columns: Array(
                repeating: GridItem(.flexible(), spacing: TrinketDesign.Spacing.small, alignment: .top),
                count: dynamicTypeSize.isAccessibilitySize ? 2 : 4,
            ), spacing: TrinketDesign.Spacing.medium) {
                ForEach(enemies) { enemy in
                    Button { inspect(enemy) } label: {
                        VStack(spacing: TrinketDesign.Spacing.extraSmall) {
                            Color.clear
                                .aspectRatio(1, contentMode: .fit)
                                .overlay {
                                    GeometryReader { geometry in
                                        enemyArtwork(enemy)
                                            .frame(width: geometry.size.width, height: geometry.size.height)
                                            .clipped()
                                    }
                                }
                                .clipShape(TrinketDesign.cardShape)
                            GameLabel(enemy.name)
                                .trinketTypography(.caption)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .trinketArtworkCardButtonStyle()
                    .accessibilityIdentifier(AccessibilityID.Voyage.destinationEnemy(enemy.id))
                }
            }
        }
    }

    private func bossSection(_ enemy: Enemy) -> some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            GameLabel(LabyrinthNodeType.boss.title, resource: LabyrinthNodeType.boss.contextualTitleResource)
                .trinketTypography(.sectionTitle)
            Button { inspect(enemy) } label: {
                HStack(spacing: TrinketDesign.Spacing.medium) {
                    enemyArtwork(enemy)
                        .frame(width: 96, height: 72)
                        .clipShape(TrinketDesign.cardShape)
                    GameLabel(enemy.name).trinketTypography(.rowDisplay)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(.secondary).accessibilityHidden(true)
                }
                .trinketSurface(.denseRow)
            }
            .trinketArtworkCardButtonStyle()
            .accessibilityIdentifier(AccessibilityID.Voyage.destinationEnemy(enemy.id))
        }
    }

    private func enemyArtwork(_ enemy: Enemy) -> some View {
        Group {
            if let art = enemy.combatant.artReference {
                MapTileArtwork(art: art, prefersThumbnail: true)
            } else {
                MapTilePlaceholder(tint: TrinketDesign.Colors.accent, icon: .system("person.fill"))
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func inspect(_ enemy: Enemy) {
        inspectedEnemy = makePlayEnemyDetail(combatant: enemy.combatant, level: level)
    }

    private var routeSection: some View {
        let nodes = route
        return VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Text(L10n.voyage_destination_route).trinketTypography(.sectionTitle)
            ForEach([LabyrinthNodeType.battle, .shop, .mystery, .recruit, .boss], id: \.self) { type in
                let count = nodes.count(where: { $0.type == type })
                if count > 0 {
                    HStack {
                        GameIconImage(GameIcon(id: type.iconID)).foregroundStyle(LabyrinthMapPresentation.tint(for: type))
                        GameLabel(type.title, resource: type.contextualTitleResource)
                        Spacer()
                        Text(count, format: .number).monospacedDigit()
                    }
                    .trinketTypography(.body)
                }
            }
        }
    }

    private var completionBonusText: String {
        var resource = L10n.voyage_destination_bonus
        resource.locale = locale
        return String(localized: resource).replacingOccurrences(of: "%%", with: "%")
    }

    private var completionSection: some View {
        VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
            Text(L10n.voyage_destination_completion)
                .trinketTypography(.sectionTitle)
                .accessibilityIdentifier(AccessibilityID.Voyage.destinationCompletion)
            HStack(alignment: .top, spacing: TrinketDesign.Spacing.small) {
                GameIconImage(reward.style.icon).foregroundStyle(reward.style.color).accessibilityHidden(true)
                KeywordDescriptionText(text: reward.description)
            }
            Text(verbatim: completionBonusText).trinketTypography(.body)
        }
    }
}
