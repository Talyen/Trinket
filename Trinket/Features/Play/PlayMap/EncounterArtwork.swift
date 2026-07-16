import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct EncounterArtwork: View {
    let stage: Stage

    @ScaledMetric(relativeTo: .largeTitle) private var placeholderIconSize: CGFloat = 42

    var body: some View {
        ZStack {
            if let combatantArt = stage.encounterCombatantArtReference {
                Image.preparedAsset(named: combatantArt.thumbnailImageName ?? combatantArt.imageName)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()

            } else if let art = stage.encounterArtReference {
                Image.preparedAsset(named: art.thumbnailImageName ?? art.imageName)
                    .resizable()
                    .scaledToFill()
                    .decorativePreparedArtwork()

            } else {
                stage.encounter.mapTint.opacity(0.14)
                Image(systemName: stage.encounter.symbolName)
                    .font(.system(size: placeholderIconSize, weight: .semibold))
                    .foregroundStyle(stage.encounter.mapTint)
                    .symbolRenderingMode(.hierarchical)
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
        if stage.encounter.battleEnemyID != nil {
            Button(action: onEnemyTap) {
                artwork
            }
            // UIStyleCheck: allow - Artwork opens enemy details without button chrome.
            .trinketQuietTapButtonStyle()
            .accessibilityIdentifier("\(stage.mapLabel) Enemy Art")

        } else {
            artwork
        }
    }

    private var artwork: some View {
        EncounterArtwork(stage: stage)
            .aspectRatio(stage.encounter.artAspectRatio, contentMode: .fit)
            .clipShape(TrinketDesign.cardShape)
            .trinketLockedCardEffect(isLocked: isLocked, text: isLocked ? "Locked" : nil)
            .accessibilityIdentifier(
                stage.encounter.mysteryEventID == nil
                    ? "\(stage.mapLabel) Encounter Art"
                    : "\(stage.mapLabel) Mystery Art"
            )
    }
}
