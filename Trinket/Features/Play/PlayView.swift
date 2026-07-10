import BattleEngine
import SwiftUI
import TrinketContent

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var stageMessage: StageMapMessage?
    @State private var playDeepLink: PlayLaunchDestination?

    var body: some View {
        @Bindable var battle = appState.battle

        // Battle stays in-tab (not a fullScreenCover) so the tab bar remains usable mid-fight.
        // Uses the Play tab NavigationStack for BattleView toolbars. Mode deep-link
        // state is preserved on PlayView and reapplied when battle ends.
        Group {
            if let configuration = battle.activeBattle {
                BattleView(configuration: configuration)
                    .id(configuration.id)
            } else {
                ChapterStageSelectView(
                    onStageTap: handleStageTap,
                    onEnemyTap: showEnemyDetails(for:),
                    onResumeMessage: { stageMessage = $0 }
                )
                .navigationDestination(item: $playDeepLink) { destination in
                    switch destination {
                    case .labyrinthMap:
                        LabyrinthMapView()
                    case let .aspectClimb(aspectID):
                        AspectClimbView(aspectID: aspectID)
                    }
                }
            }
        }
        .onAppear {
            applyPendingPlayDestinationIfNeeded()
        }
        .onChange(of: battle.activeBattle?.id) { _, newID in
            if newID == nil {
                applyPendingPlayDestinationIfNeeded()
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
                .presentationDetents([.medium])
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

    private func applyPendingPlayDestinationIfNeeded() {
        guard let destination = appState.consumePendingPlayDestination() else { return }
        switch destination {
        case .labyrinthMap:
            if appState.isLabyrinthUnlocked {
                _ = appState.enterLabyrinth()
            }
            playDeepLink = .labyrinthMap
        case let .aspectClimb(aspectID):
            playDeepLink = .aspectClimb(aspectID)
        }
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
