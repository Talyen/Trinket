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
    @State private var isFlowing = false
    @State private var isLevelUpHighlighted = false
    @State private var hasAnimated = false
    @State private var hasReportedCompletion = false
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    nonisolated static let initialDelay: TimeInterval = 0.10
    nonisolated static let animationBudget: TimeInterval = 0.70
    nonisolated static let settleDuration: TimeInterval = 0.12

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
        onAnimationCompleted: @escaping () -> Void = {},
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
        HStack(spacing: TrinketDesign.Spacing.medium) {
            if let artworkName {
                circularPortrait(artworkName: artworkName)
            }

            VStack(alignment: .leading, spacing: TrinketDesign.Spacing.small) {
                HStack(alignment: .firstTextBaseline, spacing: TrinketDesign.Spacing.small) {
                    Text(combatantName)
                        .trinketTypography(.cardLabel)

                    Spacer(minLength: TrinketDesign.Spacing.small)

                    if let experienceAward, experienceAward > 0, showsExperienceAward {
                        Text("+\(experienceAward) XP")
                            .trinketTypography(.footnote)
                            .fontWeight(.semibold)
                            .monospacedDigit()
                            .foregroundStyle(fillColor)
                            .transition(.opacity.combined(with: .scale(scale: 0.92)))
                    }
                }

                ExperienceProgress(
                    fraction: displayedFraction,
                    experience: Double(displayedXP),
                    level: displayedLevel,
                    requiredXP: displayedRequiredXP,
                    fillColor: fillColor,
                    isFlowing: isFlowing,
                    isLevelUpHighlighted: isLevelUpHighlighted,
                )
            }
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            if snapToFinal || reduceMotion {
                snapToPost()
                reportCompletion()
            } else {
                startAnimation()
            }
        }
        .onChange(of: reduceMotion) { _, isReduced in
            guard isReduced else { return }
            animationTask?.cancel()
            animationTask = nil
            snapToPost()
            reportCompletion()
        }
        .onChange(of: snapToFinal) { _, shouldSnap in
            guard shouldSnap else { return }
            animationTask?.cancel()
            animationTask = nil
            snapToPost()
            reportCompletion()
        }
        .onChange(of: pre) { _, _ in
            finishImmediately()
        }
        .onChange(of: post) { _, _ in
            finishImmediately()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            if hasAnimated {
                snapToPost()
                reportCompletion()
            }
        }
    }

    private func circularPortrait(artworkName: String) -> some View {
        let size: CGFloat = 58
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
                .accessibilityHidden(true)
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
            try? await Task.sleep(for: .seconds(Self.initialDelay))
            guard !Task.isCancelled else { return }
            withAnimation(TrinketMotion.Reward.reveal) {
                showsExperienceAward = (experienceAward ?? 0) > 0
                isFlowing = pre != post
            }
            await runSegments()
        }
    }

    private func finishImmediately() {
        animationTask?.cancel()
        animationTask = nil
        snapToPost()
        reportCompletion()
    }

    private func snapToPost() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedLevel = post.level
            displayedXP = post.currentXP
            displayedRequiredXP = post.requiredXP
            displayedFraction = post.progressFraction
            showsExperienceAward = (experienceAward ?? 0) > 0
            isFlowing = false
            isLevelUpHighlighted = false
        }
    }

    private func reportCompletion() {
        guard !hasReportedCompletion else { return }
        hasReportedCompletion = true
        onAnimationCompleted()
    }

    private func runSegments() async {
        let segments = Self.segments(from: pre, to: post)
        let movingSegmentCount = segments.count(where: { $0.startFraction != $0.endFraction })
        let segmentDuration = Self.segmentDuration(forSegmentCount: movingSegmentCount)
        let levelUpDuration = Self.levelUpDuration(forLevelCount: segments.count(where: { $0.levelsGained > 0 }))
        for segment in segments {
            guard !Task.isCancelled else { return }
            if segment.startFraction != segment.endFraction {
                await animate(to: segment, duration: segmentDuration)
            }
            guard !Task.isCancelled else { return }
            if segment.levelsGained > 0 {
                withAnimation(TrinketMotion.Reward.reveal) {
                    isLevelUpHighlighted = true
                    displayedLevel = segment.newLevel
                }
                try? await Task.sleep(for: .seconds(levelUpDuration))
                guard !Task.isCancelled else { return }
                applyLevelUp(newLevel: segment.newLevel, newRequiredXP: segment.newRequiredXP)
                withAnimation(TrinketMotion.Reward.reveal) {
                    isLevelUpHighlighted = false
                }
            }
        }
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: Self.settleDuration)) {
            isFlowing = false
        }
        if !segments.isEmpty {
            try? await Task.sleep(for: .seconds(Self.settleDuration))
        }
        guard !Task.isCancelled else { return }
        reportCompletion()
    }

    private func animate(to segment: Segment, duration: TimeInterval) async {
        withAnimation(.easeInOut(duration: duration)) {
            displayedFraction = segment.endFraction
            displayedXP = segment.endXP
        }
        try? await Task.sleep(for: .seconds(duration))
        guard !Task.isCancelled else { return }
        displayedFraction = segment.endFraction
        displayedXP = segment.endXP
    }

    private func applyLevelUp(newLevel: Int, newRequiredXP: Int) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            displayedLevel = newLevel
            displayedRequiredXP = newRequiredXP
            displayedXP = 0
            displayedFraction = 0
        }
    }

    public struct Segment: Equatable, Sendable {
        public let startFraction: Double
        public let endFraction: Double
        public let endXP: Int
        public let levelsGained: Int
        public let newLevel: Int
        public let newRequiredXP: Int
    }

    // swiftlint:disable:next modifier_order - public nonisolated is the required concurrency spelling
    public nonisolated static func segments(
        from pre: CombatantProgression,
        to post: CombatantProgression,
    ) -> [Segment] {
        if pre == post {
            return []
        }

        if post.level <= pre.level {
            return [Segment(
                startFraction: pre.progressFraction,
                endFraction: post.progressFraction,
                endXP: post.currentXP,
                levelsGained: 0,
                newLevel: post.level,
                newRequiredXP: post.requiredXP,
            )]
        }

        var segments: [Segment] = []

        segments.append(Segment(
            startFraction: pre.progressFraction,
            endFraction: 1.0,
            endXP: pre.requiredXP,
            levelsGained: 1,
            newLevel: pre.level + 1,
            newRequiredXP: CombatantProgression.requiredXP(forLevel: pre.level + 1),
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
                newRequiredXP: upcomingRequiredXP,
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
            newRequiredXP: post.requiredXP,
        ))

        return segments
    }

    nonisolated static func levelUpDuration(forLevelCount count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        return min(0.16, 0.28 / Double(count))
    }

    nonisolated static func segmentDuration(forSegmentCount count: Int) -> TimeInterval {
        guard count > 0 else { return 0 }
        return animationBudget / Double(count)
    }
}

private struct ExperienceProgress: View, Animatable {
    nonisolated var fraction: Double
    nonisolated var experience: Double
    let level: Int
    let requiredXP: Int
    let fillColor: Color
    let isFlowing: Bool
    let isLevelUpHighlighted: Bool

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(fraction, experience) }
        set {
            fraction = newValue.first
            experience = newValue.second
        }
    }

    var body: some View {
        VStack(spacing: TrinketDesign.Spacing.small) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                    Capsule()
                        .fill(fillColor)
                        .frame(width: geometry.size.width * min(1, max(0, fraction)))
                        .overlay(alignment: .trailing) {
                            if fraction > 0.02 {
                                Circle()
                                    .fill(fillColor.gradient)
                                    .brightness(isFlowing ? 0.25 : 0)
                                    .frame(width: isFlowing ? 8 : 6, height: isFlowing ? 8 : 6)
                                    .shadow(color: fillColor.opacity(isFlowing ? 0.8 : 0.4), radius: isFlowing ? 5 : 2)
                                    .alignmentGuide(.trailing) { dimensions in
                                        dimensions[HorizontalAlignment.center]
                                    }
                            }
                        }
                }
                .brightness(isLevelUpHighlighted ? 0.20 : 0)
                .scaleEffect(x: 1, y: isLevelUpHighlighted ? 1.35 : 1)
                .shadow(color: fillColor.opacity(isLevelUpHighlighted ? 0.65 : 0), radius: 6)
            }
            .frame(height: TrinketDesign.Bars.statHeight)

            HStack {
                Text("Level \(level)")
                    .contentTransition(.numericText())
                    .scaleEffect(isLevelUpHighlighted ? 1.08 : 1, anchor: .leading)
                    .foregroundStyle(isLevelUpHighlighted ? fillColor : .secondary)
                Spacer(minLength: TrinketDesign.Spacing.small)
                Text("\(Int(experience.rounded())) / \(requiredXP) XP")
                    .monospacedDigit()
            }
            .trinketTypography(.footnote)
            .foregroundStyle(.secondary)
        }
    }
}
