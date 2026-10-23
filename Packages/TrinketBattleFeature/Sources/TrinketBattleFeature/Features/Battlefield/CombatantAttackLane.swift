import SwiftUI

struct CombatantAttackMotion {
    var reaction: CombatantAttackReaction?
    var initialPose = CombatantPose.rest

    func duration(for reaction: CombatantAttackReaction, aim: CombatantAttackAim) -> TimeInterval {
        if let duration = reaction.duration {
            return duration
        }
        let timing = CombatFeedbackAttackRecipes.timing(isPartyMember: aim == .towardEnemy)
        switch reaction.phase {
        case .windUp: return timing.preparation
        case .swing: return timing.swing
        case .cancel, .recover: return timing.recovery
        case .rest: return 0
        }
    }

    func pose(at date: Date, aim: CombatantAttackAim) -> CombatantPose {
        guard let reaction else { return .rest }
        let recipe = CombatFeedbackAttackRecipes.lungeCardAttack
        let target: CombatantPose = switch reaction.phase {
        case .windUp: recipe.windUp.pose.aimed(aim)
        case .swing: recipe.swing.pose.aimed(aim)
        case .cancel, .recover, .rest: .rest
        }
        let duration = duration(for: reaction, aim: aim)
        let elapsed = max(0, (reaction.pausedAt ?? date).timeIntervalSince(reaction.startedAt))
        guard duration > 0, elapsed < duration else { return target }
        let spring: Spring = switch reaction.phase {
        case .windUp: .smooth(duration: duration)
        case .swing: .snappy(duration: duration)
        case .cancel, .recover, .rest: .bouncy(duration: duration)
        }
        let progress = spring.value(target: 1.0, time: elapsed)
        return CombatantPose(
            scaleX: initialPose.scaleX + (target.scaleX - initialPose.scaleX) * progress,
            scaleY: initialPose.scaleY + (target.scaleY - initialPose.scaleY) * progress,
            offsetX: initialPose.offsetX + (target.offsetX - initialPose.offsetX) * progress,
            offsetY: initialPose.offsetY + (target.offsetY - initialPose.offsetY) * progress,
            rotation: initialPose.rotation + (target.rotation - initialPose.rotation) * progress,
        )
    }

    mutating func adopt(_ reaction: CombatantAttackReaction?, aim: CombatantAttackAim) {
        if let reaction, reaction.id != self.reaction?.id {
            initialPose = pose(at: reaction.startedAt, aim: aim)
        }
        self.reaction = reaction
    }
}

struct CombatantAttackLane<Content: View>: View {
    @Environment(BattleSession.self) private var battleSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let combatantID: String
    let aim: CombatantAttackAim
    @ViewBuilder let content: () -> Content

    @State private var motion = CombatantAttackMotion()
    @State private var isAnimating = false
    @State private var attackBridgeOwnerID = UUID()

    var body: some View {
        let card = content()
        TimelineView(.animation(paused: reduceMotion || !isAnimating)) { timeline in
            let pose = reduceMotion ? .rest : motion.pose(at: isAnimating ? timeline.date : .now, aim: aim)
            card
                .scaleEffect(x: pose.scaleX, y: pose.scaleY)
                .rotationEffect(.degrees(pose.rotation))
                .offset(x: pose.offsetX, y: pose.offsetY)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { installAttackReactionBridge() }
        .onDisappear { battleSession.feedback.uninstallAttackReactionBridge(ownerID: attackBridgeOwnerID) }
        .onChange(of: combatantID) { _, _ in
            motion = CombatantAttackMotion()
            installAttackReactionBridge()
        }
        .task(id: motion.reaction) {
            guard let reaction = motion.reaction, reaction.pausedAt == nil else {
                isAnimating = false
                return
            }
            let remaining = max(0, motion.duration(for: reaction, aim: aim) - Date.now.timeIntervalSince(reaction.startedAt))
            isAnimating = remaining > 0
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            isAnimating = false
        }
    }

    private func installAttackReactionBridge() {
        battleSession.feedback.installAttackReactionBridge(
            ownerID: attackBridgeOwnerID, combatantID: combatantID,
        ) { reaction in
            motion.adopt(reaction, aim: aim)
        }
    }
}
