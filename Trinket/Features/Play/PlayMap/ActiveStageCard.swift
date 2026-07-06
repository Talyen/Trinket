import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ActiveStageCard: View {
    let stage: Stage
    let activeHero: Combatant
    let activePet: Combatant
    let onHeroPicker: () -> Void
    let onPetPicker: () -> Void
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    @State private var actionFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            EncounterArtworkButton(stage: stage, isLocked: false, onEnemyTap: onEnemyTap)

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .active)

                Text(stage.flavorText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ActivePartyPickerRow(
                hero: activeHero,
                pet: activePet,
                onHeroPicker: onHeroPicker,
                onPetPicker: onPetPicker
            )

            Button {
                actionFeedbackTrigger += 1
                onPrimaryAction()
            } label: {
                Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .tint(stage.encounter.mapTint)
            .accessibilityIdentifier(StageMapID.stageNode(for: stage))
            .accessibilityLabel("\(stage.mapLabel), active \(stage.encounter.title)")
            .sensoryFeedback(.selection, trigger: actionFeedbackTrigger)
        }
        .trinketSurface(.selected)
    }
}
