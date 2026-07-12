import BattleEngine
import SwiftUI
import TrinketContent
import TrinketPersistence

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var stageMessage: StageMapMessage?
    @State private var playDeepLink: PlayLaunchDestination?

    var body: some View {
        @Bindable var battle = appState.battle

        // Battle stays in-tab (not a fullScreenCover) so the tab bar remains usable mid-fight.
        // Uses the Play tab NavigationStack for BattleView toolbars. Mode deep-link
        // state is preserved on PlayView and reapplied when battle ends.
        // Active battle always wins over Mode Hub / last-mode restore.
        Group {
            if let configuration = battle.activeBattle {
                BattleView(configuration: configuration)
                    .id(configuration.id)
            } else {
                PlayModeHubView(
                    onOpenCampaign: { openMode(.campaign) },
                    onOpenAspects: { openMode(.aspects) },
                    onOpenLabyrinth: { openMode(.labyrinth) }
                )
                .navigationDestination(item: $playDeepLink) { destination in
                    destinationView(for: destination)
                }
            }
        }
        .onAppear {
            restorePlayDestinationIfNeeded()
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
            BattleLogSheet(
                entries: battle.state?.log ?? []
            )
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
                    // Dismiss only through Leave Shop — interactive dismiss is disabled.
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
        case .aspectsHub:
            AspectsHubView(onBattleStart: refreshBattlePresentation)
        case .labyrinthMap:
            LabyrinthMapView(onBattleStart: refreshBattlePresentation)
        case let .aspectClimb(aspectID):
            AspectClimbView(aspectID: aspectID, onBattleStart: refreshBattlePresentation)
        }
    }

    private func openMode(_ mode: PlayerShellSessionPlayMode) {
        guard canOpen(mode) else { return }
        appState.rememberPlayMode(mode)
        let destination: PlayLaunchDestination
        switch mode {
        case .campaign:
            destination = .campaign
        case .aspects:
            destination = .aspectsHub
        case .labyrinth:
            destination = .labyrinthMap
            _ = appState.enterLabyrinth()
        }

        // A manual back navigation can leave the item binding holding the previous
        // destination. Clear it first so reopening the same mode publishes a change.
        playDeepLink = nil
        Task { @MainActor in
            playDeepLink = destination
        }
    }

    private func canOpen(_ mode: PlayerShellSessionPlayMode) -> Bool {
        switch mode {
        case .campaign:
            true
        case .aspects:
            ModesUnlock.isUnlocked(journey: appState.journey.current)
        case .labyrinth:
            appState.isLabyrinthUnlocked
        }
    }

    /// Prefer pending post-battle / launch destinations; otherwise resume last mode.
    /// Skipped entirely while an active battle is showing.
    private func restorePlayDestinationIfNeeded() {
        guard appState.battle.activeBattle == nil else { return }

        if let destination = appState.consumePendingPlayDestination() {
            apply(destination)
            return
        }

        if playDeepLink == nil {
            let mode = appState.lastPlayMode
            guard canOpen(mode) else { return }
            apply(PlayLaunchDestination.restoring(lastMode: mode))
        }
    }

    private func apply(_ destination: PlayLaunchDestination) {
        switch destination {
        case .campaign:
            appState.rememberPlayMode(.campaign)
            playDeepLink = .campaign
        case .aspectsHub:
            appState.rememberPlayMode(.aspects)
            playDeepLink = .aspectsHub
        case .labyrinthMap:
            if appState.isLabyrinthUnlocked {
                _ = appState.enterLabyrinth()
                appState.rememberPlayMode(.labyrinth)
                playDeepLink = .labyrinthMap
            }
        case let .aspectClimb(aspectID):
            appState.rememberPlayMode(.aspects)
            playDeepLink = .aspectClimb(aspectID)
        }
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
        playDeepLink = nil
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
