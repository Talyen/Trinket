import BattleEngine
import SwiftUI
import TrinketContent

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var stageMessage: StageMapMessage?

    var body: some View {
        @Bindable var battle = appState.battle

        content
            .sheet(item: $battle.overlayCombatantDetail, onDismiss: {
                appState.battle.restorePauseAfterOverlay()
            }, content: { detail in
                CombatantDetailPane(snapshot: detail, hidesNavigationBar: true)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.resizes)
                    .presentationDragIndicator(.hidden)
            })
            .alert(item: $stageMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        if let activeBattle = appState.battle.activeBattle {
            BattleView(configuration: activeBattle)
                .id(activeBattle.id)
        } else {
            ChapterStageSelectView(
                onStageTap: handleStageTap,
                onEnemyTap: showEnemyDetails(for:)
            )
        }
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journeyProgress.isActive(stage) {
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
