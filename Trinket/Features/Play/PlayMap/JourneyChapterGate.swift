import SwiftUI
import TrinketContent
import TrinketDesignSystem

struct JourneyChapterGate: View {
    let chapter: Chapter

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ChapterArt(chapter: chapter, reduceTransparency: false)

            LinearGradient(
                colors: [.clear, .black.opacity(0.68)],
                startPoint: .center,
                endPoint: .bottom
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 8) {
                Label("Locked", systemImage: "lock.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text("Chapter \(chapter.number)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))

                Text(chapter.title.isEmpty ? "Next Chapter" : chapter.title)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .clipShape(TrinketDesign.cardShape)
        .overlay {
            TrinketDesign.cardShape
                .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StageMapID.chapterLocked(chapter))
        .accessibilityLabel("Chapter \(chapter.number), locked")
    }
}
