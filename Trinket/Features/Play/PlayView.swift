import BattleEngine
import SwiftUI

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
            .onChange(of: appState.battle.activeBattle?.id) { _, newValue in
                guard newValue == nil else { return }
                appState.journey.requestMapScroll(to: appState.mapScrollFocusID(for: appState.journey.current))
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
                activeHero: appState.roster.activeHero,
                activePet: appState.roster.activePet,
                heroes: appState.roster.heroes,
                pets: appState.roster.pets,
                onStageTap: handleStageTap,
                onEnemyTap: showEnemyDetails(for:),
                onSetActiveHero: { appState.roster.setActiveHero($0) },
                onSetActivePet: { appState.roster.setActivePet($0) }
            )
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

    private func showEnemyDetails(for stage: Stage) {
        guard let detail = enemyDetail(for: stage) else { return }
        appState.battle.presentCombatantDetail(detail)
    }

    private func enemyDetail(for stage: Stage) -> CombatantCardDetail? {
        guard let enemyID = stage.encounter.battleEnemyID,
              let enemy = GameContent.enemy(matching: enemyID),
              let chapter = GameContent.chapter(id: stage.chapterID)
        else { return nil }

        let combatant = CombatantLevelScaler.scale(
            enemy: enemy,
            level: EncounterLevelResolver.journeyEnemyLevel(for: stage, in: chapter)
        )
        return CombatantCardDetail(
            combatant: combatant,
            progression: .initial,
            equipmentLoadout: EquipmentLoadout(),
            inventoryState: appState.inventory.current,
            health: combatant.maxHealth,
            activeEffectSummaries: []
        )
    }
}
