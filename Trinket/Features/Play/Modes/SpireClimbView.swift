import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport
import TrinketPersistence

struct SpireClimbView: View {
    @Environment(PlaySession.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.displayScale) private var displayScale

    @State private var floorMessage: StageMapMessage?

    let spireID: SpireID

    private var spire: SpireDefinition? {
        GameContent.spire(id: spireID)
    }

    private var floors: [SpireFloor] {
        GameContent.spireFloors(for: spireID)
    }

    private var activeFloorNumber: Int {
        guard let spire else { return 1 }
        return appState.spires.activeFloor(for: spireID.rawValue, floorCount: spire.floorCount)
    }

    var body: some View {
        Group {
            if let spire {
                climbContent(spire)
            } else {
                ContentUnavailableView("Spire Missing", systemImage: "sparkles")
                    .trinketScreenBackground()
            }
        }
        .accessibilityIdentifier(AccessibilityID.Play.spireClimb(spireID.rawValue))
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

    private func climbContent(_ spire: SpireDefinition) -> some View {
        let rows = StageSelectRowPresentation<SpireFloor>.spireRows(
            for: spire,
            floors: floors,
            progress: appState.spires
        )

        return StageSelectScreen(
            eyebrow: "SPIRE",
            title: spire.title,
            subtitle: nil,
            titleAccessibilityIdentifier: AccessibilityID.Play.spireTitle(spire.id.rawValue)
        ) {
            spireHeroArtwork(for: spire)
        } content: {
            Group {
                if rows.isEmpty {
                    completionState(for: spire)
                } else {
                    StageSelectList(
                        rows: rows,
                        isPrimaryActionDisabled: { _ in
                            appState.battle.activeBattle != nil || !isPartyAttuned(to: spire)
                        },
                        onArtworkTap: showEnemyDetails,
                        onPrimaryAction: { floor in
                            if let message = appState.startSpireBattle(for: floor) {
                                floorMessage = message
                            }
                        },
                        artwork: { floor in
                            SpireFloorArtwork(floor: floor, tint: spire.keyword.visualStyle.color)
                        },
                        partyPickerSheet: { _ in
                            StageBattlePartyPickerSheet(spire: spire)
                        }
                    )
                }
            }
            .padding(.bottom, TrinketDesign.Metrics.compactTabBarContentClearance)
        }
    }

    @ViewBuilder
    private func spireHeroArtwork(for spire: SpireDefinition) -> some View {
        if let art = ArtCatalog.backgroundArtByID["spire-\(spire.id.rawValue)"] {
            Image.preparedAsset(named: art.imageName)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            spire.keyword.visualStyle.color
        }
    }

    private func completionState(for spire: SpireDefinition) -> some View {
        VStack(spacing: TrinketDesign.Metrics.largeSpacing) {
            ContentUnavailableView(
                "Spire Cleared",
                systemImage: "checkmark.seal.fill",
                description: Text("All \(spire.floorCount) floors are complete.")
            )

            Button("Back to The Spires") {
                dismiss()
            }
            .frame(maxWidth: .infinity)
            .trinketPrimaryActionButton(
                tint: spire.keyword.visualStyle.color,
                accessibilityIdentifier: AccessibilityID.Play.spireCompletionBack(spire.id.rawValue)
            )
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, TrinketDesign.Metrics.largeSpacing)
    }

    private func isPartyAttuned(to spire: SpireDefinition) -> Bool {
        SpireAttunement.evaluate(
            hero: appState.roster.activeHero,
            companion: appState.roster.activeCompanion,
            spire: spire
        ).isReady
    }

    private func showEnemyDetails(for floor: SpireFloor) {
        guard let encounter = ActiveBattleConfiguration.resolvedSpireEncounter(for: floor) else { return }
        appState.battle.presentCombatantDetail(
            CombatantCardDetail(
                combatant: encounter.combatant,
                inventoryState: appState.inventory
            )
        )
    }

    private func prepareActiveFloorBattle() {
        guard let floor = GameContent.spireFloor(
            spireID: spireID,
            floor: activeFloorNumber
        ) else { return }
        appState.prepareSpireBattle(for: floor)
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
            let token = ActiveBattleResumeToken.spire(
                spireID: spireID,
                floor: activeFloorNumber
            )
            let names = appState.battle.preparedAbilityArtworkNames(for: token)
            await PreparedArtworkCache.shared.prepareAndPin(names: names)
        }
    }
}

private struct SpireFloorArtwork: View {
    let floor: SpireFloor
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
                Image(systemName: "flag.2.crossed")
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(tint)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
