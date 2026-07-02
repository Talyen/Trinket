import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState
    var onPrimaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(stage.mapLabel)
                .font(.headline.weight(state == .active ? .bold : .semibold))
                .foregroundStyle(titleStyle)
                .lineLimit(1)
                .minimumScaleFactor(0.86)

            control
        }
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
    }

    private var titleStyle: Color {
        state == .future ? .secondary : .primary
    }

    @ViewBuilder
    private var control: some View {
        if state == .active {
            Button {
                onPrimaryAction?()
            } label: {
                Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .controlSize(.regular)
            .tint(encounterTint)
            .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
            .accessibilityLabel("\(stage.mapLabel), active \(stage.encounter.title)")
            .accessibilityHint("Opens the stage preview.")
        } else {
            Label(statusLabel, systemImage: statusSymbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var encounterTint: Color {
        stage.encounter.mapTint
    }

    private var statusTint: Color {
        switch state {
        case .active:
            return encounterTint
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.86)
        case .future:
            return .secondary
        }
    }

    private var statusSymbolName: String {
        switch state {
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.fill"
        case .active:
            return stage.encounter.symbolName
        }
    }

    private var chipBackground: Color {
        switch state {
        case .active:
            return encounterTint.opacity(0.12)
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.12)
        case .future:
            return Color.secondary.opacity(0.10)
        }
    }

    private var statusLabel: String {
        switch state {
        case .active:
            return stage.encounter.title
        case .completed, .justCompleted:
            return "Cleared"
        case .future:
            return "Locked"
        }
    }
}
