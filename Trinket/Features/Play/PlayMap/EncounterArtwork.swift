import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct EncounterArtwork: View {
    let stage: Stage

    var body: some View {
        ZStack {
            if let combatantArt = stage.encounterCombatantArtReference {
                Image(combatantArt.thumbnailImageName ?? combatantArt.imageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(combatantArt.accessibilityLabel)
            } else if let art = stage.encounterArtReference {
                Image(art.thumbnailImageName ?? art.imageName)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                stage.encounter.mapTint.opacity(0.14)
                Image(systemName: stage.encounter.symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(stage.encounter.mapTint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

struct EncounterArtworkButton: View {
    let stage: Stage
    let isLocked: Bool
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
            .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? "Locked" : nil)
    }
}
