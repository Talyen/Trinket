import SwiftUI
import TrinketContent

struct JourneyStageRow: View {
    let stage: Stage
    let state: StageNodeState
    let activeHero: Combatant
    let activePet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        switch state {
        case .completed, .justCompleted:
            CompletedStageRow(stage: stage)
        case .active:
            ActiveStageCard(
                stage: stage,
                activeHero: activeHero,
                activePet: activePet,
                onHeroPicker: onHeroPicker,
                onPetPicker: onPetPicker,
                onEnemyTap: onEnemyTap,
                onPrimaryAction: onPrimaryAction
            )
        case .future:
            LockedStageCard(stage: stage, onEnemyTap: onEnemyTap)
        }
    }
}
