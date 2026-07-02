import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState
    var onPrimaryAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(iconBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: statusSymbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(statusTint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(stage.mapLabel)
                        .font(.headline.weight(state == .active ? .bold : .semibold))
                        .foregroundStyle(titleStyle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Text(stage.encounter.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTint)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)
            control
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
        .background(surfaceBackground)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(borderColor, lineWidth: borderWidth)
        }
        .shadow(color: shadowColor, radius: shadowRadius, y: shadowYOffset)
        .contentShape(TrinketDesign.cardShape)
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

    private var iconBackground: Color {
        switch state {
        case .active:
            return encounterTint.opacity(0.14)
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success.opacity(0.12)
        case .future:
            return Color.secondary.opacity(0.10)
        }
    }

    private var surfaceBackground: Color {
        switch state {
        case .active:
            return Color(.secondarySystemBackground)
        case .completed, .justCompleted:
            return Color(.tertiarySystemBackground).opacity(0.72)
        case .future:
            return Color(.tertiarySystemBackground).opacity(0.56)
        }
    }

    private var borderColor: Color {
        switch state {
        case .active:
            return encounterTint.opacity(0.42)
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
        state == .active ? 6 : 0
    }

    private var shadowYOffset: CGFloat {
        state == .active ? 3 : 0
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
