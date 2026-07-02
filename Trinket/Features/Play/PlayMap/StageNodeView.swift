import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState
    var onPrimaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                encounterBadge

                VStack(alignment: .leading, spacing: 5) {
                    Text(metadataLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(labelStyle)

                    Text(statusTitle)
                        .font(.title3.weight(state == .active ? .bold : .semibold))
                        .foregroundStyle(titleStyle)
                        .lineLimit(2)
                        .minimumScaleFactor(0.84)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if state == .active {
                Button {
                    onPrimaryAction?()
                } label: {
                    Text(stage.encounter.primaryActionTitle)
                        .frame(maxWidth: .infinity)
                }
                .trinketPrimaryActionButton()
                .tint(encounterTint)
                .accessibilityIdentifier("Stage \(stage.chapterNumber)-\(stage.stageNumber) Node")
                .accessibilityHint("Opens the stage preview.")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 188, maxHeight: 232, alignment: .topLeading)
        .background(tintLayer)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(nodeStroke, lineWidth: state == .active ? 1.5 : 1)
        }
        .shadow(color: shadowColor, radius: 4, y: 2)
    }

    private var labelStyle: Color {
        state == .active ? .primary : .secondary
    }

    private var titleStyle: Color {
        state == .future ? .secondary : .primary
    }

    private var tintLayer: Color {
        switch state {
        case .active, .completed, .justCompleted:
            return Color(.secondarySystemBackground)
        case .future:
            return Color(.tertiarySystemBackground).opacity(0.68)
        }
    }

    private var nodeStroke: Color {
        state == .active ? encounterTint.opacity(0.68) : Color.secondary.opacity(0.18)
    }

    private var shadowColor: Color {
        .black.opacity(0.05)
    }

    private var encounterBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(badgeFill)
                .frame(width: 52, height: 52)

            Image(systemName: badgeSymbolName)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(badgeTint)
                .frame(width: 52, height: 52)
        }
        .accessibilityHidden(true)
    }

    private var encounterTint: Color {
        stage.encounter.mapTint
    }

    private var badgeFill: Color {
        Color.secondary.opacity(0.12)
    }

    private var badgeTint: Color {
        switch state {
        case .active:
            return encounterTint
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future:
            return .secondary
        }
    }

    private var badgeSymbolName: String {
        switch state {
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.fill"
        case .active:
            return stage.encounter.symbolName
        }
    }

    private var statusTitle: String {
        switch state {
        case .active, .completed, .justCompleted:
            return stage.title
        case .future:
            return "Unknown Path"
        }
    }

    private var metadataLabel: String {
        "\(stage.mapLabel) · \(statusLabel)"
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
