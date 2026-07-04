import SwiftUI
import TrinketContent


struct StageStatusHeader: View {
    let stage: Stage
    let state: StageNodeState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                let style = StageNodeStyle.style(for: state, encounter: stage.encounter)
                Label(stage.encounter.title, systemImage: style.symbolName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.tint)
                    .labelStyle(.titleAndIcon)

                Spacer(minLength: 8)

                Text(stage.mapLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(stage.encounterSubjectName)
                .font(.title3.weight(.bold))
                .foregroundStyle(state == .future ? .secondary : .primary)
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
    }
}
