import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct ChapterGateCardView: View {
    let chapter: Chapter

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: "lock.rectangle.on.rectangle.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text("Chapter \(chapter.number)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text("Next Chapter Locked")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text("A new route will open after this chapter is complete.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 272, alignment: .topLeading)
        .trinketSurface(.disabled)
    }
}
