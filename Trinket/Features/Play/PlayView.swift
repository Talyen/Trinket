import BattleEngine
import SwiftUI
import TrinketContent

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var stageMessage: StageMapMessage?
    @State private var labyrinthDeepLink: PlayLaunchDestination?

    var body: some View {
        @Bindable var battle = appState.battle

        ChapterStageSelectView(
            onStageTap: handleStageTap,
            onEnemyTap: showEnemyDetails(for:),
            onResumeMessage: { stageMessage = $0 }
        )
        .navigationDestination(item: $labyrinthDeepLink) { _ in
            LabyrinthMapView()
        }
        .onAppear {
            applyPendingPlayDestinationIfNeeded()
        }
        .fullScreenCover(item: activeBattleBinding) { configuration in
            NavigationStack {
                BattleView(configuration: configuration)
                    .id(configuration.id)
            }
            .interactiveDismissDisabled()
        }
        .sheet(item: $battle.overlayCombatantDetail, onDismiss: {
            appState.battle.restorePauseAfterOverlay()
        }, content: { detail in
            CombatantDetailPane(snapshot: detail, hidesNavigationBar: true)
                .presentationDetents([.large])
                .presentationContentInteraction(.resizes)
                .presentationDragIndicator(.hidden)
        })
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

    private var activeBattleBinding: Binding<ActiveBattleConfiguration?> {
        Binding(
            get: { appState.battle.activeBattle },
            set: { newValue in
                if newValue == nil, appState.battle.activeBattle != nil {
                    // Dismiss only through battle end / abandon — keep interactive dismiss disabled.
                }
            }
        )
    }

    private func applyPendingPlayDestinationIfNeeded() {
        guard appState.consumePendingPlayDestination() == .labyrinthMap else { return }
        if appState.isLabyrinthUnlocked {
            _ = appState.enterLabyrinth()
        }
        labyrinthDeepLink = .labyrinthMap
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journey.current.isActive(stage) {
            appState.noteMapScrollFocus(stage.id)
            if let message = appState.handleStagePrimaryAction(for: stage) {
                stageMessage = message
            }
        }
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
