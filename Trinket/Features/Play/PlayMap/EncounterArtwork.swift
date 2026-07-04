import SwiftUI

struct EncounterArtwork: View {
    let stage: Stage
    let isLocked: Bool

    var body: some View {
        ZStack {
            if let art = stage.encounterArtReference {
                Image(art.thumbnailImageName ?? art.imageName)
                    .resizable()
                    .scaledToFill()
                    .saturation(isLocked ? 0.48 : 1)
                    .opacity(isLocked ? 0.72 : 1)
                    .blur(radius: isLocked ? 4 : 0)
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                stage.encounter.mapTint.opacity(0.14)
                    .blur(radius: isLocked ? 4 : 0)
                Image(systemName: stage.encounter.symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(stage.encounter.mapTint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
                    .blur(radius: isLocked ? 4 : 0)
            }

            if isLocked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.52), radius: 8, y: 2)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
