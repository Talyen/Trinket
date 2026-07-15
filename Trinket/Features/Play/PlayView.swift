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
                .trinketDetailSheet(dragIndicator: .hidden)
        })
        .sheet(item: $battle.overlayAbilityDetail, content: { ability in
            NavigationStack {
                AbilityDetailView(ability: ability)
                    .accessibilityIdentifier(AccessibilityID.Battle.abilityDetail)
            }
            .trinketDetailSheet(dragIndicator: .hidden)
        })
        .sheet(isPresented: $battle.isShowingBattleLog) {
            BattleLogSheet(entries: battle.state?.log ?? [])
                .presentationDetents([.medium])
        }
        .fullScreenCover(
            item: dismissibleSessionBinding(
                get: { appState.activeMysteryEncounter },
                dismissWithoutCompleting: { appState.dismissActiveMysteryEncounterWithoutCompleting() }
            )
        ) { session in
            MysteryEncounterView(session: session)
                .interactiveDismissDisabled()
        }
        .fullScreenCover(
            item: dismissibleSessionBinding(
                get: { appState.activeShopEncounter },
                dismissWithoutCompleting: { appState.dismissActiveShopEncounterWithoutCompleting() }
            )
        ) { session in
            ShopEncounterView(session: session)
                .interactiveDismissDisabled()
        }
        .sheet(
            item: dismissibleSessionBinding(
                get: { appState.activeLabyrinthNodeSession },
                dismissWithoutCompleting: { appState.dismissActiveLabyrinthNodeSessionWithoutCompleting() }
            )
        ) { session in
            switch session.kind {
            case .rest:
                LabyrinthRestView(session: session)
            case .craft:
                LabyrinthCraftView(session: session)
            }
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

    /// Sheet/cover dismiss sets `nil`; route that through the incomplete-dismiss path
    /// instead of dropping the session without cleanup.
    private func dismissibleSessionBinding<Session>(
        get: @escaping () -> Session?,
        dismissWithoutCompleting: @escaping () -> Void
    ) -> Binding<Session?> {
        Binding(
            get: get,
            set: { newValue in
                if newValue == nil, get() != nil {
                    dismissWithoutCompleting()
                }
            }
        )
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
        if appState.journey.isActive(stage) {
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
            inventoryState: appState.inventory
        )
    }
}
