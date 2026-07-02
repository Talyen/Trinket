import SwiftUI

struct StagePreviewHeader: View {
    let stage: Stage
    let subject: StagePreviewSubject
    let baseHeight: CGFloat
    let coordinateSpaceName: String

    static func headerHeight(forWidth width: CGFloat) -> CGFloat {
        min(max(width * 1.04, 340), 430)
    }

    var body: some View {
        GeometryReader { geometry in
            let pullDistance = max(geometry.frame(in: .named(coordinateSpaceName)).minY, 0)
            let scale = HeroHeaderLayout.overscrollScale(baseHeight: baseHeight, pullDistance: pullDistance)

            ZStack(alignment: .topLeading) {
                headerArt(width: geometry.size.width, height: baseHeight)
                    .scaleEffect(scale, anchor: .top)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.65)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .allowsHitTesting(false)

                titleBlock
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
            .frame(height: baseHeight + pullDistance)
            .clipped()
            .offset(y: -pullDistance)
        }
        .frame(height: baseHeight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stage \(stage.chapterNumber)-\(stage.stageNumber), \(subject.type), \(subject.name)")
    }

    @ViewBuilder
    private func headerArt(width: CGFloat, height: CGFloat) -> some View {
        if let combatant = subject.combatant {
            CombatantArtwork(combatant: combatant, variant: .hero)
                .frame(width: width, height: height)
                .clipped()
        } else {
            ZStack {
                subject.tint.opacity(0.18)

                Image(systemName: subject.symbolName)
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(subject.tint)
                    .symbolRenderingMode(.hierarchical)
                    .accessibilityHidden(true)
            }
            .frame(width: width, height: height)
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stage \(stage.chapterNumber)-\(stage.stageNumber)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))

            Text(subject.type.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.8))

            Text(subject.name)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
    }
}
