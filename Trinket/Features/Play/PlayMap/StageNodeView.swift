import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState
    var onPrimaryAction: (() -> Void)?

    @State private var previewFeedbackTrigger = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            Spacer(minLength: 8)

            control
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
        .background {
            TrinketDesign.cardShape
                .fill(surfaceColor)
        }
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(borderColor, lineWidth: borderWidth)
        }
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
        .contentShape(TrinketDesign.cardShape)
        .sensoryFeedback(.selection, trigger: previewFeedbackTrigger)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            iconWell

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.mapLabel)
                    .font(.headline.weight(state == .active ? .bold : .semibold))
                    .foregroundStyle(titleStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.88)

                Text(stageSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(subtitleStyle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.86)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var iconWell: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(iconBackground)

            Image(systemName: style.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(statusTint)
                .symbolRenderingMode(.hierarchical)
        }
        .frame(width: 38, height: 38)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var control: some View {
        if state == .active {
            Button {
                previewFeedbackTrigger += 1
                onPrimaryAction?()
            } label: {
                Label(stage.encounter.primaryActionTitle, systemImage: stage.encounter.symbolName)
                    .frame(maxWidth: .infinity)
            }
            .trinketPrimaryActionButton()
            .controlSize(.regular)
            .tint(stage.encounter.mapTint)
            .accessibilityIdentifier(StageMapID.stageNode(for: stage))
            .accessibilityLabel("\(stage.mapLabel), active \(stage.encounter.title), \(stageSubtitle)")
            .accessibilityHint("Opens the stage preview.")
        } else {
            Label(style.label, systemImage: style.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(statusTint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(chipBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var stageSubtitle: String {
        switch stage.encounter {
        case let .battle(enemyID):
            return GameContent.enemy(matching: enemyID)?.name ?? "Unknown Enemy"
        case .event:
            return "Mystery"
        case .shop:
            return "Merchant"
        case .rest:
            return "Moonwell"
        }
    }

    private var style: StageNodeStyle {
        StageNodeStyle.style(for: state, encounter: stage.encounter)
    }

    private var titleStyle: Color {
        state == .future ? .secondary : .primary
    }

    private var subtitleStyle: Color {
        state == .future ? .secondary : .primary.opacity(0.72)
    }

    private var statusTint: Color {
        switch state {
        case .active:
            return stage.encounter.mapTint
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.86)
        case .future:
            return .secondary
        }
    }

    private var iconBackground: Color {
        switch state {
        case .active:
            return stage.encounter.mapTint.opacity(0.14)
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.12)
        case .future:
            return Color.secondary.opacity(0.10)
        }
    }

    private var surfaceColor: Color {
        switch state {
        case .active:
            return Color(.secondarySystemBackground)
        case .completed, .justCompleted:
            return Color(.tertiarySystemBackground).opacity(0.78)
        case .future:
            return Color(.tertiarySystemBackground).opacity(0.58)
        }
    }

    private var borderColor: Color {
        switch state {
        case .active:
            return stage.encounter.mapTint.opacity(0.46)
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.24)
        case .future:
            return Color.secondary.opacity(0.16)
        }
    }

    private var borderWidth: CGFloat {
        state == .active ? 1.5 : 1
    }

    private var shadowColor: Color {
        state == .active ? Color.black.opacity(0.10) : Color.clear
    }

    private var shadowRadius: CGFloat {
        state == .active ? 7 : 0
    }

    private var shadowYOffset: CGFloat {
        state == .active ? 3 : 0
    }

    private var chipBackground: Color {
        switch state {
        case .active:
            return stage.encounter.mapTint.opacity(0.12)
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.12)
        case .future:
            return Color.secondary.opacity(0.10)
        }
    }
}
