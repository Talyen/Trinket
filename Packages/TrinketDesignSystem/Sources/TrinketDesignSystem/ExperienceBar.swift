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
    @State private var levelUpBurst: Int?
    @State private var hasAnimated = false
    @State private var hasReportedCompletion = false
    @State private var animationTask: Task<Void, Never>?

    private let initialDelay: TimeInterval = 0.25
    private let segmentDuration: TimeInterval = 0.4
    private let levelUpFlashInDuration: TimeInterval = 0.18
    private let levelUpFlashHoldDuration: TimeInterval = 0.18
    private let levelUpFlashOutDuration: TimeInterval = 0.18

    public init(
        combatantName: String,
        artworkName: String? = nil,
        pre: CombatantProgression,
        post: CombatantProgression,
        fillColor: Color,
        experienceAward: Int? = nil,
        snapToFinal: Bool = false,
        onAnimationCompleted: @escaping () -> Void = {}
    ) {
        self.combatantName = combatantName
        self.artworkName = artworkName
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
        HStack(spacing: 12) {
            if let artworkName {
                Image(artworkName)
                    .resizable()
                    .interpolation(.low)
                    .scaledToFill()
                    .frame(width: 58, height: 58)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(fillColor.opacity(0.82), lineWidth: 1.5)
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(combatantName)
                        .font(.subheadline.weight(.semibold))

                    if let burstLevel = levelUpBurst {
                        Text("Level \(burstLevel)!")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(TrinketDesign.Colors.Overlay.paper)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(TrinketDesign.Colors.progression, in: Capsule())
                            .transition(.scale.combined(with: .opacity))
                    }

                    Spacer(minLength: 8)

                    if let experienceAward, experienceAward > 0 {
                        Text("+\(experienceAward) XP")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(fillColor)
                    }
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(.quaternary)

                        Capsule()
                            .fill(fillColor)
                            .frame(width: geometry.size.width * displayedFraction)

                        if displayedFraction > 0.02 {
                            Circle()
                                .fill(fillColor)
                                .frame(width: 7, height: 7)
                                .shadow(color: fillColor.opacity(0.85), radius: 5)
                                .offset(x: max(0, geometry.size.width * displayedFraction - 4))
                        }
                    }
                }
                .frame(height: TrinketDesign.Metrics.statBarHeight)

                HStack {
                    Text("Level \(displayedLevel)")
                    Spacer(minLength: 8)
                    Text("\(displayedXP) / \(displayedRequiredXP) XP")
                        .monospacedDigit()
                }
                .font(.caption)
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
        }
    }

    private var levelLabel: String {
        if pre.level == post.level {
            return "Experience, level \(post.level)"
        }
        return "Experience, level \(pre.level) to \(post.level)"
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
    }

    private func reportCompletion() {
        guard !hasReportedCompletion else { return }
        hasReportedCompletion = true
        onAnimationCompleted()
    }

    private func runSegments(clock: SuspendingClock) async {
        let segments = Self.segments(from: pre, to: post)
        for segment in segments {
            guard !Task.isCancelled else { return }
            await animate(to: segment, clock: clock)
            guard !Task.isCancelled else { return }
            if segment.levelsGained > 0 {
                await showLevelUpFlash(newLevel: segment.newLevel, newRequiredXP: segment.newRequiredXP, clock: clock)
            }
        }
        guard !Task.isCancelled else { return }
        reportCompletion()
    }

    private func animate(to segment: Segment, clock: SuspendingClock) async {
        withAnimation(.easeOut(duration: segmentDuration)) {
            displayedFraction = segment.endFraction
            displayedXP = segment.endXP
        }
        try? await clock.sleep(for: .seconds(segmentDuration), tolerance: .milliseconds(25))
    }

    private func showLevelUpFlash(newLevel: Int, newRequiredXP: Int, clock: SuspendingClock) async {
        displayedLevel = newLevel
        displayedRequiredXP = newRequiredXP
        displayedXP = 0
        displayedFraction = 0

        withAnimation(.easeOut(duration: levelUpFlashInDuration)) {
            levelUpBurst = newLevel
        }
        try? await clock.sleep(for: .seconds(levelUpFlashHoldDuration), tolerance: .milliseconds(25))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: levelUpFlashOutDuration)) {
            levelUpBurst = nil
        }
        try? await clock.sleep(for: .seconds(levelUpFlashOutDuration), tolerance: .milliseconds(25))
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
}
