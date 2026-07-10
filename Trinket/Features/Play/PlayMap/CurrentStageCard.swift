import SwiftUI
import TrinketContent
import TrinketDesignSystem

/// Focused current-stage presentation — art, identity, narrative, CTA.
struct CurrentStageCard: View {
    @Environment(AppState.self) private var appState

    let stage: Stage
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    @State private var actionFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            EncounterArtworkButton(stage: stage, isLocked: false, onEnemyTap: onEnemyTap)

            VStack(alignment: .leading, spacing: 6) {
                Text(stage.encounterSubjectName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(stage.mapLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(stage.flavorText)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            if stage.encounter.battleEnemyID != nil {
                BattlePartyInlinePicker(accentColor: stage.encounter.mapTint)
            }

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
            .trinketSensoryFeedback(
                .selection,
                trigger: actionFeedbackTrigger,
                enabled: appState.options.hapticsEnabled
            )
        }
    }
}
