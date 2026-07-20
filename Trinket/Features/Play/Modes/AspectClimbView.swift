import SwiftUI
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketPersistence

struct AspectClimbView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    @State private var floorMessage: StageMapMessage?

    let aspectID: AspectID

    private var aspect: AspectDefinition? {
        GameContent.aspect(id: aspectID)
    }

    private var floors: [AspectFloor] {
        GameContent.aspectFloors(for: aspectID)
    }

    private var activeFloorNumber: Int {
        guard let aspect else { return 1 }
        return appState.aspects.activeFloor(for: aspectID.rawValue, floorCount: aspect.floorCount)
    }

    var body: some View {
        Group {
            if let aspect {
                climbContent(aspect)
            } else {
                ContentUnavailableView("Aspect Missing", systemImage: "sparkles")
                    .trinketScreenBackground()
            }
        }
        .accessibilityIdentifier(AccessibilityID.Play.aspectClimb(aspectID.rawValue))
        .alert(item: $floorMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            prepareActiveFloorBattle()
            warmActiveFloorPresentation()
        }
        .onChange(of: activeFloorNumber) { _, _ in
            prepareActiveFloorBattle()
        }
        .onChange(of: appState.roster) { _, _ in
            prepareActiveFloorBattle()
        }
        .onChange(of: appState.inventory) { _, _ in
            prepareActiveFloorBattle()
        }
        .onChange(of: appState.homestead) { _, _ in
            prepareActiveFloorBattle()
        }
    }

    private func climbContent(_ aspect: AspectDefinition) -> some View {
        let rows = StageSelectRowPresentation<AspectFloor>.aspectRows(
            for: aspect,
            floors: floors,
            progress: appState.aspects
        )

        return StageSelectScreen(
            eyebrow: "ASPECT",
            title: aspect.title,
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Play.aspectTitle(aspect.id.rawValue)
        ) {
            aspectHeroArtwork(for: aspect)
        } content: {
            Group {
                if rows.isEmpty {
                    completionState(for: aspect)
                } else {
                    StageSelectList(
                        rows: rows,
                        isPrimaryActionDisabled: { _ in
                            appState.battle.activeBattle != nil || !isPartyAttuned(to: aspect)
                        },
                        onArtworkTap: showEnemyDetails,
                        onPrimaryAction: { floor in
                            if let message = appState.startAspectBattle(for: floor) {
                                floorMessage = message
                            }
                        },
                        artwork: { floor in
                            AspectFloorArtwork(floor: floor, tint: aspect.keyword.visualStyle.color)
                        },
                        partyPickerSheet: { _ in
                            StageBattlePartyPickerSheet(aspect: aspect)
                        }
                    )
                }
            }
            .padding(.bottom, TrinketDesign.Metrics.compactTabBarContentClearance)
        }
    }

    @ViewBuilder
    private func aspectHeroArtwork(for aspect: AspectDefinition) -> some View {
        if let art = ArtCatalog.backgroundArtByID["aspect-\(aspect.id.rawValue)"] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            aspect.keyword.visualStyle.color
        }
    }

    private func completionState(for aspect: AspectDefinition) -> some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            ContentUnavailableView(
                "Aspect Cleared",
                systemImage: "checkmark.seal.fill",
                description: Text("All \(aspect.floorCount) floors are complete.")
            )

            Button("Back to Aspects") {
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .trinketPrimaryActionButton(
                tint: aspect.keyword.visualStyle.color,
                accessibilityIdentifier: AccessibilityID.Play.aspectCompletionBack(aspect.id.rawValue)
            )
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
    }

    private func isPartyAttuned(to aspect: AspectDefinition) -> Bool {
        AspectAttunement.evaluate(
            hero: appState.roster.activeHero,
            companion: appState.roster.activeCompanion,
            aspect: aspect
        ).isReady
    }

    private func showEnemyDetails(for floor: AspectFloor) {
        guard let encounter = ActiveBattleConfiguration.resolvedAspectEncounter(for: floor) else { return }
        appState.battle.presentCombatantDetail(
            CombatantCardDetail(
                combatant: encounter.combatant,
                inventoryState: appState.inventory
            )
        )
    }

    private func prepareActiveFloorBattle() {
        guard let floor = GameContent.aspectFloor(
            aspectID: aspectID,
            floor: activeFloorNumber
        ) else { return }
        appState.prepareAspectBattle(for: floor)
    }

    private func warmActiveFloorPresentation() {
        Task { @MainActor in
            await Task.yield()
            await BattlePresentationWarmup.prepareAndWait(
                dynamicTypeSize: dynamicTypeSize,
                displayScale: displayScale
            )
            appState.battle.prepareBattlePresentation(
                heroUltimateID: appState.roster.activeHero.abilityLoadout.ultimate?.id,
                companionUltimateID: appState.roster.activeCompanion.abilityLoadout.ultimate?.id
            )
            let token = ActiveBattleResumeToken.aspect(
                aspectID: aspectID,
                floor: activeFloorNumber
            )
            let names = appState.battle.preparedAbilityArtworkNames(for: token)
            await PreparedArtworkCache.shared.prepareAndPin(names: names)
        }
    }
}

private struct AspectFloorArtwork: View {
    let floor: AspectFloor
    let tint: Color

    @ScaledMetric(relativeTo: .largeTitle) private var placeholderIconSize: CGFloat = 42

    var body: some View {
        ZStack {
            if let combatant = GameContent.enemy(matching: floor.enemyID)?.combatant,
               let art = combatant.artReference {
                Image.preparedAsset(named: art.thumbnailImageName ?? art.imageName)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()
            } else {
                tint.opacity(0.14)
                Image(systemName: "bolt.fill")
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
