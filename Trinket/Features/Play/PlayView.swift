import SwiftUI

struct PlayView: View {
    @Environment(AppState.self) private var appState
    @State private var selectedStage: Stage?
    @State private var stageMessage: StageMapMessage?

    var body: some View {
        @Bindable var battle = appState.battle

        content
            .sheet(item: $selectedStage) { stage in
                StagePreviewSheet(
                    stage: stage,
                    chapter: GameContent.chapter(containing: stage),
                    onPrimaryAction: { handlePrimaryAction(for: stage) }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
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
            .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
                guard newValue == nil else { return }
                appState.journey.requestMapScroll(to: appState.mapScrollFocusID(for: appState.journey.current))
            }
            .onChange(of: selectedStage?.id) { _, _ in
                appState.battle.setMusicPreview(for: selectedStage)
            }
    }

    @ViewBuilder
    private var content: some View {
        if let activeBattle = appState.battle.activeBattle {
            BattleView(configuration: activeBattle)
                .id(activeBattle.id)
        } else {
            ChapterStageSelectView(
                chapter: appState.playChapter,
                progress: appState.journey.current,
                onStageTap: handleStageTap
            )
        }
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journey.current.isActive(stage) {
            selectedStage = stage
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
            } else {
                selectedStage = nil
            }
        case .event, .shop, .rest:
            appState.completeStage(stage, hero: appState.roster.activeHero, pet: appState.roster.activePet)
            selectedStage = nil
        }
    }
}
