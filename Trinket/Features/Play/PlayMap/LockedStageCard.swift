import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct LockedStageCard: View {
    let stage: Stage
    let onEnemyTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockedEncounterArtworkButton(stage: stage, onEnemyTap: onEnemyTap)

            VStack(alignment: .leading, spacing: 8) {
                StageStatusHeader(stage: stage, state: .future)

                Text(stage.flavorText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .trinketSurface(.disabled)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.stageNode(for: stage))
        .accessibilityLabel("\(stage.mapLabel), locked \(stage.encounter.title), \(stage.encounterSubjectName)")
    }
}

private struct LockedEncounterArtworkButton: View {
    let stage: Stage
    let onEnemyTap: () -> Void

    var body: some View {
        Group {
            if stage.encounter.battleEnemyID != nil {
                Button(action: onEnemyTap) {
                    artwork
                }
                // UIStyleCheck: allow - Artwork opens enemy details without button chrome.
                .buttonStyle(.plain)
                .accessibilityIdentifier("\(stage.mapLabel) Enemy Art")
                .accessibilityLabel("\(stage.mapLabel), \(stage.encounterSubjectName) details")
            } else {
                artwork
            }
        }
    }

    private var artwork: some View {
        EncounterArtwork(stage: stage)
            .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
            .clipShape(TrinketDesign.cardShape)
            .trinketLockedCardEffect(isLocked: true, text: "Locked")
    }
}
