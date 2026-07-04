import SwiftUI
import TrinketContent
import TrinketDesignSystem


struct CompletedStageRow: View {
    let stage: Stage

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(TrinketDesign.Colors.success.opacity(0.12))

                Image(systemName: "checkmark.circle.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .symbolRenderingMode(.hierarchical)
            }
            .frame(width: 44, height: 44)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(stage.mapLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(stage.encounterSubjectName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("Cleared")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TrinketDesign.Colors.success)
        }
        .padding(12)
        .background(Color(.tertiarySystemBackground).opacity(0.54), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.stageNode(for: stage))
        .accessibilityLabel("\(stage.mapLabel), complete, \(stage.encounterSubjectName)")
    }
}
