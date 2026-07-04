import SwiftUI
import TrinketContent

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
