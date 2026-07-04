import SwiftUI

struct StageStatusHeader: View {
    let stage: Stage
    let state: StageNodeState

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(stage.encounterSubjectName)
                .font(.title3.weight(.bold))
                .foregroundStyle(state == .future ? .secondary : .primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 8)

            Text(stage.mapLabel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}
