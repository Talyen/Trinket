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
                    .accessibilityLabel(art.accessibilityLabel)
            } else {
                stage.encounter.mapTint.opacity(0.14)
                Image(systemName: stage.encounter.symbolName)
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(stage.encounter.mapTint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }

            if isLocked {
                Rectangle()
                    .fill(.black.opacity(0.22))
                    .accessibilityHidden(true)

                Label("Locked", systemImage: "lock.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.36), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity)
        .clipped()
    }
}
