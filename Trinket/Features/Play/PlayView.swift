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
            ChapterStageSelectView(
                onStageTap: handleStageTap,
                onEnemyTap: showEnemyDetails(for:)
            )
        }
    }

    private func handleStageTap(_ stage: Stage) {
        if appState.journey.current.isActive(stage) {
            appState.sessionState.mapScrollStageID = stage.id
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
        case .event, .shop, .rest, .mysteryEvent:
            appState.completeStage(stage, hero: appState.roster.activeHero, pet: appState.roster.activePet)
        }
    }

    private func showEnemyDetails(for stage: Stage) {
        guard let detail = enemyDetail(for: stage) else { return }
        appState.battle.presentCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let encounter = StageEncounterResolver.resolve(for: stage) else { return nil }

        return CombatantCardDetail(
            combatant: encounter.combatant,
            progression: .initial,
            equipmentLoadout: EquipmentLoadout(),
            inventoryState: appState.inventory.current,
            health: encounter.combatant.maxHealth,
            activeEffectSummaries: []
        )
    }
}
