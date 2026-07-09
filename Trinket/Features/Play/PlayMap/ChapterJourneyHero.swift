import SwiftUI
import TrinketContent
import TrinketDesignSystem
import TrinketPersistence

struct ChapterJourneyHero: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let chapter: Chapter
    let overscroll: CGFloat

    private var modesUnlocked: Bool {
        ModesUnlock.isUnlocked(journey: appState.journey.current)
    }

    var body: some View {
        GeometryReader { geometry in
            let baseHeight = max(480, geometry.size.height * 0.70)

            OverscrollHeroContainer(
                baseHeight: baseHeight,
                overscroll: overscroll
            ) {
                ChapterArt(chapter: chapter, reduceTransparency: reduceTransparency)
            } overlay: {
                ZStack(alignment: .bottomLeading) {
                    LinearGradient(
                        colors: [
                            .black.opacity(0.06),
                            .clear,
                            .black.opacity(0.92)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Chapter \(chapter.number)")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.84))
                            Spacer(minLength: 8)
                            modesEntryControl
                        }

                        Text(chapter.title)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .minimumScaleFactor(0.76)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .shadow(color: .black.opacity(0.48), radius: 8, y: 2)
                    .accessibilityIdentifier(AccessibilityID.Play.chapterHeader(number: chapter.number))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .containerRelativeFrame(.vertical) { length, _ in
            max(480, length * 0.70)
        }
        .clipped()
        .backgroundExtensionEffect()
        .ignoresSafeArea(edges: .top)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var modesEntryControl: some View {
        if modesUnlocked {
            NavigationLink {
                ModesView()
            } label: {
                modesChipLabel(locked: false)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(AccessibilityID.Play.modesEntry)
        } else {
            modesChipLabel(locked: true)
                .accessibilityIdentifier(AccessibilityID.Play.modesEntry)
                .accessibilityHint(ModesUnlock.unlockHint)
        }
    }

    private func modesChipLabel(locked: Bool) -> some View {
        Label(locked ? "Modes Locked" : "Modes", systemImage: locked ? "lock.fill" : "sparkles")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .opacity(locked ? 0.72 : 1)
            .trinketGlassChip()
    }
}
