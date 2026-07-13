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
        .padding(.horizontal, TrinketDesign.Metrics.contentMargin)
        .padding(.vertical, 12)
    }
}

private struct ChapterStageRow: View {
    let presentation: ChapterStageRowPresentation
    let onEnemyTap: () -> Void
    let onPrimaryAction: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
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
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(
            AccessibilityID.Play.stageRow(
                chapter: presentation.stage.chapterNumber,
                stage: presentation.stage.stageNumber
            )
        )
    }

    private var compactRow: some View {
        compactRowLabel
    }

    private var compactRowLabel: some View {
        HStack(spacing: 10) {
            EncounterArtwork(stage: presentation.stage)
                // UIStyleCheck: allow - Fixed 4:3 thumbnail keeps the five-stage path compact.
                .frame(width: 74, height: 55.5)
                .trinketArtworkBlend(.perimeter(into: .surface))
                .clipShape(TrinketDesign.cardShape)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.stage.encounterSubjectName)
                    .trinketTypography(.rowDisplay)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                StageMapMetaLine(stage: presentation.stage, showsEncounterIcon: true)
            }

            Spacer(minLength: 4)

            if presentation.isCompleted {
                Image(systemName: "checkmark")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TrinketDesign.Colors.success)
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 68)
        .trinketSurface(.denseRow)
        .clipShape(TrinketDesign.cardShape)
        .opacity(presentation.state == .future ? 0.72 : 1)
    }
}
