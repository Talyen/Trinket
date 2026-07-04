import SwiftUI
import TrinketContent
import TrinketDesignSystem


struct LockedStageCard: View {
    let stage: Stage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            EncounterArtwork(stage: stage, isLocked: true)
                .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
                .clipShape(TrinketDesign.cardShape)

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .future)

                Text(stage.flavorText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(Color(.tertiarySystemBackground).opacity(0.70), in: TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.stageNode(for: stage))
        .accessibilityLabel("\(stage.mapLabel), locked \(stage.encounter.title), \(stage.encounterSubjectName)")
    }
}
