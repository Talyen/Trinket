import SwiftUI
import TrinketAppState
import TrinketBattleFeature
import TrinketContent
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureAdapters
import TrinketFeatureContracts
import TrinketFeatureSupport
import TrinketPersistence

struct SpireClimbView: View {
    @Environment(SpiresPlayMode.self) private var spires
    @Environment(BattleSession.self) private var battle
    @Environment(PlayerSaveStore.self) private var playerSave
    @Environment(\.dismiss) private var dismiss

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
        return playerSave.spires.activeFloor(for: spireID.rawValue, floorCount: spire.floorCount)
    }

    private var prepareBattleDependency: StageSelectPrepareDependency? {
        guard GameContent.spireFloor(spireID: spireID, floor: activeFloorNumber) != nil else {
            return nil
        }
        return .spire(spireID: spireID, floor: activeFloorNumber, playerSave: playerSave)
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
        .task(id: prepareBattleDependency) {
            prepareActiveFloorBattle()
        }
    }

    private func climbContent(_ spire: SpireDefinition) -> some View {
        let rows = StageSelectRowPresentation<SpireFloor>.spireRows(
            for: spire,
            floors: floors,
            progress: playerSave.spires
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
                            battle.lifecyclePhase == .active || !isPartyAttuned(to: spire)
                        },
                        onArtworkTap: showEnemyDetails,
                        onPrimaryAction: { floor in
                            if let message = spires.startBattle(for: floor) {
                                floorMessage = message
                            }
                        },
                        artwork: { floor, isActive in
                            SpireFloorArtwork(
                                floor: floor,
                                tint: spire.keyword.visualStyle.color,
                                prefersThumbnail: !isActive
                            )
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
            Image.preparedAsset(art, displaySize: .full)
                .resizable()
                .scaledToFill()
                .decorativePreparedArtwork()
        } else {
            spire.keyword.visualStyle.color
        }
    }

    private func completionState(for spire: SpireDefinition) -> some View {
        StageSelectCompletionPanel(
            title: "Spire Cleared",
            description: "All \(spire.floorCount) floors are complete.",
            buttonTitle: "Back to The Spires",
            tint: spire.keyword.visualStyle.color,
            accessibilityIdentifier: AccessibilityID.Play.spireCompletionBack(spire.id.rawValue),
            onBack: { dismiss() }
        )
    }

    private func isPartyAttuned(to spire: SpireDefinition) -> Bool {
        SpireAttunement.evaluate(
            hero: playerSave.roster.activeHero,
            companion: playerSave.roster.activeCompanion,
            spire: spire
        ).isReady
    }

    private func showEnemyDetails(for floor: SpireFloor) {
        guard let encounter = spires.resolvedEncounter(for: floor) else { return }
        battle.presentCombatantDetail(
            CombatantCardDetail(
                combatant: encounter.combatant
            )
        )
    }

    private func prepareActiveFloorBattle() {
        guard let floor = GameContent.spireFloor(
            spireID: spireID,
            floor: activeFloorNumber
        ) else { return }
        spires.prepareBattle(for: floor)
    }
}

private struct SpireFloorArtwork: View {
    let floor: SpireFloor
    let tint: Color
    let prefersThumbnail: Bool

    @ScaledMetric(relativeTo: .largeTitle) private var placeholderIconSize: CGFloat = 42

    var body: some View {
        ZStack {
            if let combatant = GameContent.enemy(matching: floor.enemyID)?.combatant,
               let art = combatant.artReference {
                Image.preparedAsset(
                    art,
                    displaySize: prefersThumbnail ? .compact : .full
                )
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
