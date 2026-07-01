import SwiftUI

struct ExperienceBar: View {
    let combatantName: String
    let pre: CombatantProgression
    let post: CombatantProgression
    let fillColor: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayedLevel: Int
    @State private var displayedXP: Int
    @State private var displayedRequiredXP: Int
    @State private var displayedFraction: Double
    @State private var levelUpBurst: Int?
    @State private var hasAnimated = false
    @State private var animationTask: Task<Void, Never>?

    private let initialDelay: TimeInterval = 0.25
    private let segmentDuration: TimeInterval = 0.4
    private let levelUpFlashInDuration: TimeInterval = 0.18
    private let levelUpFlashHoldDuration: TimeInterval = 0.18
    private let levelUpFlashOutDuration: TimeInterval = 0.18

    init(
        combatantName: String,
        pre: CombatantProgression,
        post: CombatantProgression,
        fillColor: Color
    ) {
        self.combatantName = combatantName
        self.pre = pre
        self.post = post
        self.fillColor = fillColor
        _displayedLevel = State(initialValue: pre.level)
        _displayedXP = State(initialValue: pre.currentXP)
        _displayedRequiredXP = State(initialValue: pre.requiredXP)
        _displayedFraction = State(initialValue: pre.progressFraction)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(combatantName) — Level \(displayedLevel)")
                    .font(.subheadline.weight(.semibold))

                if let burstLevel = levelUpBurst {
                    Text("Level \(burstLevel)!")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TrinketDesign.Colors.progression, in: Capsule())
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }

                Spacer(minLength: 8)

                Text("\(displayedXP)/\(displayedRequiredXP) XP")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)

                    Capsule()
                        .fill(fillColor)
                        .frame(width: geometry.size.width * displayedFraction)
                }
            }
            .frame(height: TrinketDesign.Metrics.statBarHeight)
            .clipShape(Capsule())
        }
        .onAppear {
            guard !hasAnimated else { return }
            hasAnimated = true
            startAnimation()
        }
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(levelLabel)
        .accessibilityValue("\(post.currentXP) of \(post.requiredXP) experience")
    }

    private var levelLabel: String {
        if pre.level == post.level {
            return "Experience, level \(post.level)"
        }
        return "Experience, level \(pre.level) to \(post.level)"
    }

    private func startAnimation() {
        if reduceMotion {
            snapToPost()
            return
        }
        animationTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(initialDelay * 1000000000))
            guard !Task.isCancelled else { return }
            await runSegments()
        }
    }

    private func snapToPost() {
        displayedLevel = post.level
        displayedXP = post.currentXP
        displayedRequiredXP = post.requiredXP
        displayedFraction = post.progressFraction
    }

    private func runSegments() async {
        let segments = Self.segments(from: pre, to: post)
        for segment in segments {
            guard !Task.isCancelled else { return }
            await animate(to: segment)
            guard !Task.isCancelled else { return }
            if segment.levelsGained > 0 {
                await showLevelUpFlash(newLevel: segment.newLevel, newRequiredXP: segment.newRequiredXP)
            }
        }
    }

    private func animate(to segment: Segment) async {
        withAnimation(.easeOut(duration: segmentDuration)) {
            displayedFraction = segment.endFraction
            displayedXP = segment.endXP
        }
        try? await Task.sleep(nanoseconds: UInt64(segmentDuration * 1000000000))
    }

    private func showLevelUpFlash(newLevel: Int, newRequiredXP: Int) async {
        displayedLevel = newLevel
        displayedRequiredXP = newRequiredXP
        displayedXP = 0
        displayedFraction = 0

        withAnimation(.easeOut(duration: levelUpFlashInDuration)) {
            levelUpBurst = newLevel
        }
        try? await Task.sleep(nanoseconds: UInt64(levelUpFlashHoldDuration * 1000000000))
        guard !Task.isCancelled else { return }
        withAnimation(.easeIn(duration: levelUpFlashOutDuration)) {
            levelUpBurst = nil
        }
        try? await Task.sleep(nanoseconds: UInt64(levelUpFlashOutDuration * 1000000000))
    }

    struct Segment: Equatable {
        let startFraction: Double
        let endFraction: Double
        let endXP: Int
        let levelsGained: Int
        let newLevel: Int
        let newRequiredXP: Int
    }

    static func segments(
        from pre: CombatantProgression,
        to post: CombatantProgression
    ) -> [Segment] {
        if pre == post { return [] }

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
            newRequiredXP: pre.requiredXP + 50
        ))

        var nextLevel = pre.level + 1
        var nextRequiredXP = pre.requiredXP + 50
        while nextLevel < post.level {
            segments.append(Segment(
                startFraction: 0.0,
                endFraction: 1.0,
                endXP: nextRequiredXP,
                levelsGained: 1,
                newLevel: nextLevel + 1,
                newRequiredXP: nextRequiredXP + 50
            ))
            nextLevel += 1
            nextRequiredXP += 50
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
