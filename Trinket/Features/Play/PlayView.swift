import BattleEngine
import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var stageMessage: StageMapMessage?
    @State private var navigationPath: [PlayLaunchDestination] = []

    var body: some View {
        @Bindable var battle = appState.battle

        // Keep the Play stack explicit so Explore's temporary sub-modes have a
        // stable hierarchy and normal tab entry always returns to the chooser.
        NavigationStack(path: $navigationPath) {
            Group {
                if let configuration = battle.activeBattle {
                    // Battle stays in-tab, preserving its existing shell and
                    // immediate return token while the mode stack is hidden.
                    BattleView(configuration: configuration)
                        .id(configuration.id)
                } else {
                    PlayModeHubView(
                        onOpenCampaign: { openMode(.campaign) },
                        onOpenExplore: { openMode(.explore) }
                    )
                }
            }
            .navigationDestination(for: PlayLaunchDestination.self) { destination in
                destinationView(for: destination)
            }
        }
        .onAppear {
            restorePlayDestinationIfNeeded()
        }
        .onChange(of: appState.selectedTab) { previousTab, newTab in
            guard newTab == .play, previousTab != .play else { return }
            // A normal Play-tab visit is a fresh choice. Pending destinations
            // are consumed only for battle/deep-link restoration below.
            guard appState.battle.activeBattle == nil else { return }
            restorePlayDestinationIfNeeded(resetForNormalEntry: true)
        }
        .onChange(of: battle.activeBattle?.id) { _, newID in
            if newID == nil {
                restorePlayDestinationIfNeeded()
            }
        }
        .sheet(item: $battle.overlayCombatantDetail, content: { detail in
            CombatantDetailPane(snapshot: detail, hidesNavigationBar: true)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        })
        .sheet(item: Binding(
            get: { battle.overlayAbilityDetail.map { AbilityDetailSheetItem(ability: $0) } },
            set: { newValue in
                if newValue == nil {
                    battle.clearAbilityDetail()
                }
            }
        ), content: { item in
            AbilityDetailSheet(ability: item.ability)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        })
        .sheet(isPresented: Binding(
            get: { battle.isShowingBattleLog },
            set: { isShowing in
                if !isShowing {
                    battle.clearBattleLog()
                }
            }
        )) {
            BattleLogSheet(entries: battle.state?.log ?? [])
                .presentationDetents([.medium])
        }
        .fullScreenCover(
            item: Binding(
                get: { appState.activeMysteryEncounter },
                set: { newValue in
                    if newValue == nil, appState.activeMysteryEncounter != nil {
                        appState.dismissActiveMysteryEncounterWithoutCompleting()
                    }
                }
            )
        ) { session in
            MysteryEncounterView(session: session)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            item: Binding(
                get: { appState.activeShopEncounter },
                set: { newValue in
                    if newValue == nil, appState.activeShopEncounter != nil {
                        appState.dismissActiveShopEncounterWithoutCompleting()
                    }
                }
            )
        ) { session in
            ShopEncounterView(session: session)
                .interactiveDismissDisabled()
        }
        .sheet(
            item: Binding(
                get: { appState.activeLabyrinthRest },
                set: { newValue in
                    if newValue == nil, appState.activeLabyrinthRest != nil {
                        appState.dismissActiveLabyrinthRestWithoutCompleting()
                    }
                }
            )
        ) { session in
            LabyrinthRestView(session: session)
        }
        .sheet(
            item: Binding(
                get: { appState.activeLabyrinthCraft },
                set: { newValue in
                    if newValue == nil, appState.activeLabyrinthCraft != nil {
                        appState.dismissActiveLabyrinthCraftWithoutCompleting()
                    }
                }
            )
        ) { session in
            LabyrinthCraftView(session: session)
        }
        .alert(item: $stageMessage) { message in
            Alert(
                title: Text(message.title),
                message: Text(message.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private func destinationView(for destination: PlayLaunchDestination) -> some View {
        switch destination {
        case .campaign:
            ChapterStageSelectView(
                onStageTap: handleStageTap,
                onEnemyTap: showEnemyDetails(for:)
            )
        case .explore:
            ExploreHubView()
        case .aspectsHub:
            AspectsHubView(onBattleStart: refreshBattlePresentation)
        case .labyrinthMap:
            LabyrinthMapView(onBattleStart: refreshBattlePresentation)
        case let .aspectClimb(aspectID):
            AspectClimbView(aspectID: aspectID, onBattleStart: refreshBattlePresentation)
        }
    }

    private func openMode(_ destination: PlayLaunchDestination) {
        guard appState.battle.activeBattle == nil else { return }

        navigationPath.append(destination)
    }

    /// Prefer pending post-battle / launch destinations. Otherwise leave the
    /// explicit path empty so the mode chooser is the Play root.
    private func restorePlayDestinationIfNeeded(resetForNormalEntry: Bool = false) {
        guard appState.battle.activeBattle == nil else { return }

        if let destination = appState.consumePendingPlayDestination() {
            apply(destination)
            return
        }

        if resetForNormalEntry {
            navigationPath.removeAll()
        }
    }

    private func apply(_ destination: PlayLaunchDestination) {
        let path: [PlayLaunchDestination]
        switch destination {
        case .campaign:
            path = [.campaign]
        case .explore:
            path = [.explore]
        case .aspectsHub:
            path = [.explore, .aspectsHub]
        case .labyrinthMap:
            _ = appState.enterLabyrinth()
            path = [.explore, .labyrinthMap]
        case let .aspectClimb(aspectID):
            path = [.explore, .aspectsHub, .aspectClimb(aspectID)]
        }

        navigationPath = path
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journey.current.isActive(stage) {
            appState.noteMapScrollFocus(stage.id)
            if let message = appState.handleStagePrimaryAction(for: stage) {
                stageMessage = message
            } else if stage.encounter.battleEnemyID != nil {
                refreshBattlePresentation()
            }
        }
    }

    private func refreshBattlePresentation() {
        // The active battle replaces the route. The persisted resume token is
        // consumed when the battle ends, rebuilding the complete hierarchy.
        navigationPath.removeAll()
    }

    private func showEnemyDetails(for stage: Stage) {
        guard let detail = enemyDetail(for: stage) else { return }
        appState.battle.presentCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let encounter = ActiveBattleConfiguration.resolvedEncounter(for: stage) else { return nil }

        return CombatantCardDetail(
            combatant: encounter.combatant,
            inventoryState: appState.inventory.current
        )
    }
}
