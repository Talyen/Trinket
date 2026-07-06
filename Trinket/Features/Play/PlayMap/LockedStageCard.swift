import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct LockedStageCard: View {
    let stage: Stage
    let onEnemyTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EncounterArtworkButton(stage: stage, isLocked: true, onEnemyTap: onEnemyTap)

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .future)

                Text(stage.flavorText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .trinketSurface(.disabled)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.stageNode(for: stage))
        .accessibilityLabel("\(stage.mapLabel), locked \(stage.encounter.title), \(stage.encounterSubjectName)")
    }
}
