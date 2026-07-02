import SwiftUI

struct StageNodeView: View {
    let stage: Stage
    let state: StageNodeState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                encounterBadge

                VStack(alignment: .leading, spacing: 5) {
                    Text(stage.mapLabel)
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

            VStack(alignment: .leading, spacing: 10) {
                if state == .future {
                    Text("The path ahead has not revealed itself.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label(statusLabel, systemImage: statusSymbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(statusTint)

                    Text(stage.flavorText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)

            if state == .active {
                HStack {
                    Label("Preview", systemImage: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(encounterTint)
                        .labelStyle(.titleAndIcon)

                    Spacer()
                }
                .padding(.top, 2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 272, alignment: .topLeading)
        .background(tintLayer)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(nodeStroke, lineWidth: state == .active ? 1.5 : 1)
        }
        .shadow(color: shadowColor, radius: state == .active ? 14 : 4, y: state == .active ? 8 : 2)
    }

    private var labelStyle: Color {
        state == .active ? .primary : .secondary
    }

    private var titleStyle: Color {
        state == .future ? .secondary : .primary
    }

    private var tintLayer: Color {
        switch state {
        case .active:
            return Color(.secondarySystemBackground)
        case .completed, .justCompleted:
            return Color(.secondarySystemBackground).opacity(0.72)
        case .future:
            return Color(.tertiarySystemBackground).opacity(0.68)
        }
    }

    private var nodeStroke: Color {
        state == .active ? encounterTint.opacity(0.68) : Color.secondary.opacity(0.18)
    }

    private var shadowColor: Color {
        state == .active ? encounterTint.opacity(0.24) : .black.opacity(0.05)
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
        switch state {
        case .active:
            return encounterTint.opacity(0.20)
        case .completed, .justCompleted, .future:
            return Color.secondary.opacity(0.12)
        }
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

    private var statusSymbolName: String {
        switch state {
        case .active:
            return stage.encounter.symbolName
        case .completed, .justCompleted:
            return "checkmark.circle.fill"
        case .future:
            return "lock.fill"
        }
    }

    private var statusTint: Color {
        switch state {
        case .active:
            return encounterTint
        case .completed, .justCompleted:
            return TrinketDesign.Colors.success
        case .future:
            return .secondary
        }
    }
}
