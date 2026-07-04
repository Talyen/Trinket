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
            }, content: { selection in
                CombatantCollectionDetailSheet(selection: selection)
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
            ChapterStageSelectView(onStageTap: handleStageTap)
        }
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journey.current.isActive(stage) {
            handlePrimaryAction(for: stage)
        }
    }

    private func handlePrimaryAction(for stage: Stage) {
        switch stage.encounter {
        case .battle:
            if let message = appState.battle.startBattle(
                stage: stage,
                hero: appState.roster.activeHero,
                pet: appState.roster.activePet,
                roster: appState.roster,
                inventory: appState.inventory
            ) {
                stageMessage = message
            }
        case .event, .shop, .rest:
            appState.completeStage(stage, hero: appState.roster.activeHero, pet: appState.roster.activePet)
        }
    }
}
