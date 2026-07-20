import SwiftUI
import TrinketCore

public struct ExperienceBar: View {
    public let combatantName: String
    public let artworkName: String?
    public let pre: CombatantProgression
    public let post: CombatantProgression
    public let fillColor: Color
    public let experienceAward: Int?
    public let snapToFinal: Bool
    public let onAnimationCompleted: () -> Void

    @State private var displayedLevel: Int
    @State private var displayedXP: Int
    @State private var displayedRequiredXP: Int
    @State private var displayedFraction: Double
    @State private var showsExperienceAward = false
    @State private var hasAnimated = false
    @State private var hasReportedCompletion = false
    @State private var animationTask: Task<Void, Never>?

    private let initialDelay: TimeInterval = 0.10
    private let segmentSteps = 24

    nonisolated static let animationBudget: TimeInterval = 0.30

    /// Normalized crop anchor for circular combatant thumbs. Portrait art is 3:4;
    /// a center crop clips heads, so default toward the upper body / face.
    private let artworkFocalX: Double
    private let artworkFocalY: Double

    public init(
        combatantName: String,
        artworkName: String? = nil,
        artworkFocalX: Double = 0.50,
        artworkFocalY: Double = 0.30,
        pre: CombatantProgression,
        post: CombatantProgression,
        fillColor: Color,
        experienceAward: Int? = nil,
        snapToFinal: Bool = false,
        onAnimationCompleted: @escaping () -> Void = {}
    ) {
        self.combatantName = combatantName
        self.artworkName = artworkName
        self.artworkFocalX = artworkFocalX
        self.artworkFocalY = artworkFocalY
        self.pre = pre
        self.post = post
        self.fillColor = fillColor
        self.experienceAward = experienceAward
        self.snapToFinal = snapToFinal
        self.onAnimationCompleted = onAnimationCompleted
        _displayedLevel = State(initialValue: pre.level)
        _displayedXP = State(initialValue: pre.currentXP)
        _displayedRequiredXP = State(initialValue: pre.requiredXP)
        _displayedFraction = State(initialValue: pre.progressFraction)
    }

    public var body: some View {
        HStack(spacing: TrinketDesign.Metrics.mediumSpacing) {
            if let artworkName {
                circularPortrait(artworkName: artworkName)
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Metrics.denseSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Metrics.smallSpacing) {
                    Text(combatantName)
                        .trinketTypography(.cardLabel)

                    Spacer(minLength: TrinketDesign.Metrics.smallSpacing)

                    if let experienceAward, experienceAward > 0, showsExperienceAward {
                        Text("+\(experienceAward) XP")
                            .trinketTypography(.footnote)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(fillColor)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)

                        Capsule()
                            .fill(fillColor)
                            .frame(width: max(0, geometry.size.width * displayedFraction))
                            .overlay(alignment: .trailing) {
                                if displayedFraction > 0.02 {
                                    Circle()
                                        .fill(fillColor)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: fillColor.opacity(0.4), radius: 2)
                                        .alignmentGuide(.trailing) { dimensions in
                                            dimensions[HorizontalAlignment.center]
                                        }
                                }
                            }
                    }
                }
                .frame(height: TrinketDesign.Metrics.statBarHeight)

                HStack {
                    Text("Level \(displayedLevel)")
                    Spacer(minLength: TrinketDesign.Metrics.smallSpacing)
                    Text("\(displayedXP) / \(displayedRequiredXP) XP")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .trinketTypography(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            if snapToFinal {
                snapToPost()
                reportCompletion()
            } else {
                startAnimation()
            }
        }
        .onChange(of: snapToFinal) { _, shouldSnap in
            guard shouldSnap else { return }
            animationTask?.cancel()
            animationTask = nil
            snapToPost()
            reportCompletion()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            // Cancel without completion left Victory CTA locked when @State survived.
            if hasAnimated {
                snapToPost()
                reportCompletion()
            }
        }
    }

    private func circularPortrait(artworkName: String) -> some View {
        let size: CGFloat = 58
        // Combatant thumbs are authored at 3:4; match HomesteadFocalArtwork offset math.
        let sourceAspectRatio: CGFloat = 3.0 / 4.0

        return GeometryReader { geometry in
            let container = geometry.size
            let scale = max(container.width / sourceAspectRatio, container.height)
            let renderedWidth = sourceAspectRatio * scale
            let renderedHeight = scale
            let overflowX = max(renderedWidth - container.width, 0)
            let overflowY = max(renderedHeight - container.height, 0)
            let offsetX = (0.5 - artworkFocalX) * overflowX
            let offsetY = (0.5 - artworkFocalY) * overflowY

            Image(artworkName)
                .resizable()
                .interpolation(.low)
                .scaledToFill()
                .frame(width: container.width, height: container.height)
                .offset(x: offsetX, y: offsetY)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            Circle()
                .stroke(fillColor.opacity(0.82), lineWidth: 1.5)
        }
    }

    private func startAnimation() {
        animationTask = Task { @MainActor in
            let clock = SuspendingClock()
            try? await clock.sleep(for: .seconds(initialDelay), tolerance: .milliseconds(25))
            guard !Task.isCancelled else { return }
            await runSegments(clock: clock)
        }
    }

    private func snapToPost() {
        displayedLevel = post.level
        displayedXP = post.currentXP
        displayedRequiredXP = post.requiredXP
        displayedFraction = post.progressFraction
        showsExperienceAward = (experienceAward ?? 0) > 0
    }

    private func reportCompletion() {
        guard !hasReportedCompletion else { return }
        hasReportedCompletion = true
        if (experienceAward ?? 0) > 0 {
            withAnimation(TrinketMotion.Content.fade) {
                showsExperienceAward = true
            }
        }
        onAnimationCompleted()
    }

    private func runSegments(clock: SuspendingClock) async {
        let segments = Self.segments(from: pre, to: post)
        let segmentDuration = Self.segmentDuration(forSegmentCount: segments.count)
        for segment in segments {
            guard !Task.isCancelled else { return }
            await animate(to: segment, duration: segmentDuration, clock: clock)
            guard !Task.isCancelled else { return }
            if segment.levelsGained > 0 {
                applyLevelUp(newLevel: segment.newLevel, newRequiredXP: segment.newRequiredXP)
            }
        }
        guard !Task.isCancelled else { return }
        reportCompletion()
    }

    private func animate(
        to segment: Segment,
        duration: TimeInterval,
        clock: SuspendingClock
    ) async {
        let startFraction = segment.startFraction
        let endFraction = segment.endFraction
        let startXP = displayedXP
        let endXP = segment.endXP

        displayedFraction = startFraction

        let stepCount = max(1, segmentSteps)
        let stepDuration = duration / Double(stepCount)

        for step in 1 ... stepCount {
            guard !Task.isCancelled else { return }
            let t = Self.easeInOut(Double(step) / Double(stepCount))
            displayedFraction = startFraction + (endFraction - startFraction) * t
            displayedXP = startXP + Int((Double(endXP - startXP) * t).rounded())
            try? await clock.sleep(for: .seconds(stepDuration), tolerance: .milliseconds(8))
        }

        displayedFraction = endFraction
        displayedXP = endXP
    }

    private func applyLevelUp(newLevel: Int, newRequiredXP: Int) {
        displayedLevel = newLevel
        displayedRequiredXP = newRequiredXP
        displayedXP = 0
        displayedFraction = 0
    }

    private static func easeInOut(_ t: Double) -> Double {
        if t < 0.5 {
            return 2 * t * t
        }
        let inverted = -2 * t + 2
        return 1 - (inverted * inverted) / 2
    }

    public struct Segment: Equatable, Sendable {
        public let startFraction: Double
        public let endFraction: Double
        public let endXP: Int
        public let levelsGained: Int
        public let newLevel: Int
        public let newRequiredXP: Int
    }

    // swiftlint:disable:next modifier_order
    public nonisolated static func segments(
        from pre: CombatantProgression,
        to post: CombatantProgression
    ) -> [Segment] {
        if pre == post {
            return []
        }

        if pre.level == post.level {
            return [Segment(
                startFraction: pre.progressFraction,
                endFraction: post.progressFraction,
                endXP: post.currentXP,
                levelsGained: 0,
                newLevel: post.level,
                newRequiredXP: post.requiredXP
            )]
        }

        var segments: [Segment] = []

        segments.append(Segment(
            startFraction: pre.progressFraction,
            endFraction: 1.0,
            endXP: pre.requiredXP,
            levelsGained: 1,
            newLevel: pre.level + 1,
            newRequiredXP: CombatantProgression.requiredXP(forLevel: pre.level + 1)
        ))

        var nextLevel = pre.level + 1
        var nextRequiredXP = CombatantProgression.requiredXP(forLevel: nextLevel)
        while nextLevel < post.level {
            let upcomingLevel = nextLevel + 1
            let upcomingRequiredXP = CombatantProgression.requiredXP(forLevel: upcomingLevel)
            segments.append(Segment(
                startFraction: 0.0,
                endFraction: 1.0,
                endXP: nextRequiredXP,
                levelsGained: 1,
                newLevel: upcomingLevel,
                newRequiredXP: upcomingRequiredXP
            ))
            nextLevel = upcomingLevel
            nextRequiredXP = upcomingRequiredXP
        }

        segments.append(Segment(
            startFraction: 0.0,
            endFraction: post.progressFraction,
            endXP: post.currentXP,
            levelsGained: 0,
            newLevel: post.level,
            newRequiredXP: post.requiredXP
        ))

        return segments
    }

    nonisolated static func segmentDuration(forSegmentCount count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        return animationBudget / Double(count)
    }
}
