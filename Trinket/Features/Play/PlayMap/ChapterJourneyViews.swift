import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ChapterStageList: View {
    let rows: [ChapterStageRowPresentation]
    let onEnemyTap: (Stage) -> Void
    let onPrimaryAction: (Stage) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                ChapterStageRow(
                    presentation: row,
                    onEnemyTap: { onEnemyTap(row.stage) },
                    onPrimaryAction: { onPrimaryAction(row.stage) }
                )
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, 12)
    }
}

private struct ChapterStageRow: View {
    let presentation: ChapterStageRowPresentation
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        // Keep rail→card spacing identical for active and compact rows so card
        // leading edges and widths stay aligned down the path.
        HStack(alignment: .center, spacing: 14) {
            stageRail
                .frame(width: PathNodeMetrics.railWidth)

            Group {
                if presentation.isActionable {
                    CurrentStageCard(
                        stage: presentation.stage,
                        onEnemyTap: onEnemyTap,
                        onPrimaryAction: onPrimaryAction
                    )
                } else {
                    compactRow
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
        VerticalPathRail(
            minHeight: 76,
            connectorBefore: presentation.connectorBefore,
            connectorAfter: presentation.connectorAfter,
            style: .homesteadAccent
        ) {
            StageNode(
                symbolName: presentation.stage.encounter.symbolName,
                state: presentation.state,
                isBoss: presentation.isBoss
            )
            .accessibilityIdentifier(StageMapID.stageNode(for: presentation.stage))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(presentation.stage.mapLabel), \(presentation.accessibilityStatus)")
        }
    }

    private var compactRow: some View {
        compactRowLabel
    }

    private var compactRowLabel: some View {
        HStack(spacing: 10) {
            EncounterArtwork(stage: presentation.stage)
                // UIStyleCheck: allow - Fixed 4:3 thumbnail keeps the five-stage path compact.
                .frame(width: 64, height: 48)
                .clipShape(TrinketDesign.cardShape)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.stage.encounterSubjectName)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                StageMapMetaLine(stage: presentation.stage)
            }

            Spacer(minLength: 4)

            if presentation.isCompleted {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.success)
                    .accessibilityLabel("Completed")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 68)
        .trinketSurface(.denseRow)
        .clipShape(TrinketDesign.cardShape)
        .opacity(presentation.state == .future ? 0.72 : 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(compactAccessibilityLabel)
    }

    private var compactAccessibilityLabel: String {
        let boss = presentation.isBoss ? ", Boss" : ""
        return "\(presentation.stage.mapMetaLabel), \(presentation.stage.encounterSubjectName), "
            + "\(presentation.accessibilityStatus)\(boss)"
    }
}

private struct StageNode: View {
    let symbolName: String
    let state: StageNodeState
    let isBoss: Bool

    private var isProgressed: Bool {
        state != .future
    }

    private var isEmphasized: Bool {
        state == .active
    }

    var body: some View {
        ZStack {
            PathNodeChrome(
                stroke: isProgressed ? TrinketDesign.Colors.accent : Color.secondary.opacity(0.65),
                emphasized: isEmphasized
            ) {
                Image(systemName: symbolName)
                    .font(PathNodeMetrics.glyphFont(emphasized: isEmphasized))
                    .foregroundStyle(isProgressed ? .primary : .secondary)
                    .symbolRenderingMode(.hierarchical)
            }

            if isEmphasized {
                Image(systemName: "arrowtriangle.right.fill")
                    .font(.caption2)
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .offset(x: 30)
                    .accessibilityHidden(true)
            }

            if isBoss {
                Image(systemName: "crown.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.accent)
                    .offset(y: -37)
                    .accessibilityHidden(true)
            }
        }
        .shadow(
            color: isEmphasized
                ? .clear
                : isProgressed ? TrinketDesign.Colors.accent.opacity(0.28) : .clear,
            radius: isEmphasized ? 0 : 3
        )
    }
}
