import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ChapterStageList: View {
    let rows: [ChapterStageRowPresentation]
    let expandedStageID: String?
    let onToggleExpansion: (Stage) -> Void
    let onEnemyTap: (Stage) -> Void
    let onPrimaryAction: (Stage) -> Void

    @Namespace private var stageNamespace

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                ChapterStageRow(
                    presentation: row,
                    isExpanded: expandedStageID == row.stage.id,
                    namespace: stageNamespace,
                    onToggleExpansion: { onToggleExpansion(row.stage) },
                    onEnemyTap: { onEnemyTap(row.stage) },
                    onPrimaryAction: { onPrimaryAction(row.stage) }
                )
            }
        }
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, 12)
    }
}

private struct ChapterStageRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let presentation: ChapterStageRowPresentation
    let isExpanded: Bool
    let namespace: Namespace.ID
    let onToggleExpansion: () -> Void
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    private let railWidth: CGFloat = 54
    private let nodeSize: CGFloat = 48
    private let nodeTopInset: CGFloat = 8

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            stageRail
                .frame(width: railWidth)

            Group {
                if isExpanded {
                    CurrentStageCard(
                        stage: presentation.stage,
                        namespace: namespace,
                        onEnemyTap: onEnemyTap,
                        onPrimaryAction: onPrimaryAction
                    )
                    .transition(detailTransition)
                } else {
                    compactRow
                        .transition(detailTransition)
                }
            }
            .padding(.vertical, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            AccessibilityID.Play.stageRow(
                chapter: presentation.stage.chapterNumber,
                stage: presentation.stage.stageNumber
            )
        )
    }

    private var stageRail: some View {
        GeometryReader { geometry in
            let centerY = nodeTopInset + nodeSize / 2

            ZStack(alignment: .top) {
                if let connectorBefore = presentation.connectorBefore {
                    connector(connectorBefore)
                        .frame(height: max(centerY - nodeSize / 2, 0))
                }

                if let connectorAfter = presentation.connectorAfter {
                    connector(connectorAfter)
                        .frame(height: max(geometry.size.height - centerY - nodeSize / 2, 0))
                        .offset(y: centerY + nodeSize / 2)
                }

                node
                    .frame(width: nodeSize, height: nodeSize)
                    .offset(y: nodeTopInset)
            }
            .frame(maxWidth: .infinity)
        }
        // UIStyleCheck: allow - The rail follows the dynamic stage-card height.
        .frame(minHeight: 76)
    }

    private func connector(_ state: StageConnectorState) -> some View {
        Capsule()
            .fill(state == .progressed ? HomesteadPalette.accent : Color.secondary.opacity(0.38))
            .frame(width: state == .progressed ? 3 : 2)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var node: some View {
        let nodeContent = StageNumberNode(
            number: presentation.stage.stageNumber,
            state: presentation.state,
            isBoss: presentation.isBoss
        )

        if presentation.isActionable {
            Button(action: onToggleExpansion) {
                nodeContent
            }
            .buttonStyle(.plain)
            .contentShape(Circle())
            .accessibilityLabel("\(presentation.stage.mapLabel), \(presentation.accessibilityStatus)")
            .accessibilityHint(isExpanded ? "Collapse stage details" : "Expand stage details")
        } else {
            nodeContent
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(presentation.stage.mapLabel), \(presentation.accessibilityStatus)")
        }
    }

    @ViewBuilder
    private var compactRow: some View {
        if presentation.isActionable {
            Button(action: onToggleExpansion) {
                compactRowLabel
            }
            .trinketNavigationRowButtonStyle()
            .accessibilityHint("Expand stage details")
        } else {
            compactRowLabel
        }
    }

    private var compactRowLabel: some View {
        HStack(spacing: 10) {
            EncounterArtwork(stage: presentation.stage)
                // UIStyleCheck: allow - Fixed row thumbnail keeps the five-stage path compact.
                .frame(width: 54, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: TrinketDesign.Corners.small, style: .continuous))
                .matchedGeometryEffect(id: "\(presentation.stage.id)-art", in: namespace)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.stage.encounterSubjectName)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .matchedGeometryEffect(id: "\(presentation.stage.id)-title", in: namespace)

                HStack(spacing: 4) {
                    Text(presentation.stage.mapLabel)
                    Text("·")
                    Image(systemName: presentation.stage.encounter.symbolName)
                        .accessibilityHidden(true)
                    Text(presentation.stage.encounterTypeTitle)
                        .foregroundStyle(presentation.stage.encounter.mapTint)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            if presentation.isCompleted {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .accessibilityLabel("Completed")
            } else if presentation.isBoss {
                bossBadge
            } else if presentation.isActionable {
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 68)
        .trinketSurface(.denseRow)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            if presentation.isBoss {
                TrinketDesign.cardShape
                    .strokeBorder(HomesteadPalette.accent.opacity(0.72), lineWidth: 2)
                    .padding(2)
            }
        }
        .opacity(presentation.state == .future ? 0.72 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compactAccessibilityLabel)
    }

    private var bossBadge: some View {
        Label("BOSS", systemImage: "crown.fill")
            .font(.caption2.weight(.bold))
            .foregroundStyle(HomesteadPalette.accent)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(HomesteadPalette.accent.opacity(0.12), in: Capsule())
            .accessibilityIdentifier(
                AccessibilityID.Play.bossBadge(
                    chapter: presentation.stage.chapterNumber,
                    stage: presentation.stage.stageNumber
                )
            )
    }

    private var compactAccessibilityLabel: String {
        let boss = presentation.isBoss ? ", Boss" : ""
        return "\(presentation.stage.mapLabel), \(presentation.stage.encounterSubjectName), "
            + "\(presentation.stage.encounterTypeTitle), \(presentation.accessibilityStatus)\(boss)"
    }

    private var detailTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .opacity.combined(with: .scale(scale: 0.985, anchor: .topLeading))
    }
}

private struct StageNumberNode: View {
    let number: Int
    let state: StageNodeState
    let isBoss: Bool

    private var isProgressed: Bool {
        state != .future
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(.secondarySystemBackground))

            Circle()
                .strokeBorder(
                    isProgressed ? HomesteadPalette.accent : Color.secondary.opacity(0.65),
                    lineWidth: state == .active ? 3 : 2
                )

            if state == .active {
                Circle()
                    .strokeBorder(HomesteadPalette.accent.opacity(0.42), lineWidth: 1)
                    .padding(-4)
            }

            Text(number.formatted())
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(isProgressed ? .primary : .secondary)

            if state == .active {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.caption2)
                    .foregroundStyle(HomesteadPalette.accent)
                    .offset(x: 30)
                    .accessibilityHidden(true)
            }

            if isBoss {
                Image(systemName: "crown.fill")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HomesteadPalette.accent)
                    .offset(y: -31)
                    .accessibilityHidden(true)
            }
        }
        .shadow(
            color: isProgressed ? HomesteadPalette.accent.opacity(0.28) : .clear,
            radius: state == .active ? 8 : 3
        )
    }
}
