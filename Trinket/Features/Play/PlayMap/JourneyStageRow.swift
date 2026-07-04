import SwiftUI
import TrinketContent

struct JourneyStageRow: View {
    let node: VisibleStageNode
    let activeHero: Combatant
    let activePet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        switch node.state {
        case .completed, .justCompleted:
            CompletedStageRow(stage: node.stage)
        case .active:
            ActiveStageCard(
                stage: node.stage,
                activeHero: activeHero,
                activePet: activePet,
                onHeroPicker: onHeroPicker,
                onPetPicker: onPetPicker,
                onEnemyTap: onEnemyTap,
                onPrimaryAction: onPrimaryAction
            )
        case .future:
            LockedStageCard(stage: node.stage, onEnemyTap: onEnemyTap)
        }
    }
}
