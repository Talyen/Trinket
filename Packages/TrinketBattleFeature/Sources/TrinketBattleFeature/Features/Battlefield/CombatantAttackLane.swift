import SwiftUI
import TrinketDesignSystem
import TrinketFeatureSupport

/// Whole-card attack telegraph (art + bars + border). Pose springs support
/// wind-up hold, swing+recover, cancel-to-rest, and enemy full auto-play.
struct CombatantAttackLane<Content: View>: View {
    @Environment(BattleSession.self) private var battleSession
    let combatantID: String
    let aim: CombatantAttackAim
    @ViewBuilder let content: () -> Content

    @State private var pose = CombatantAttackPose.rest
    @State private var latestReactionID = 0
    @State private var phaseGeneration = 0
    @State private var attackBridgeOwnerID = UUID()

    var body: some View {
        content()
            .scaleEffect(x: pose.scaleX, y: pose.scaleY)
            .rotationEffect(.degrees(pose.rotation))
            .offset(x: pose.offsetX, y: pose.offsetY)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                installAttackReactionBridge()
                adoptLatestAttackIfNeeded()
            }
            .onDisappear {
                battleSession.feedback.uninstallAttackReactionBridge(ownerID: attackBridgeOwnerID)
            }
            .onChange(of: combatantID) { _, _ in
                installAttackReactionBridge()
                adoptLatestAttackIfNeeded()
            }
    }

    private func installAttackReactionBridge() {
        battleSession.feedback.installAttackReactionBridge(
            ownerID: attackBridgeOwnerID,
            combatantID: combatantID
        ) {
            adoptLatestAttackIfNeeded()
        }
    }

    private func adoptLatestAttackIfNeeded() {
        guard let reaction = battleSession.feedback.attackReactionsByCombatantID[combatantID],
              reaction.id != latestReactionID
        else { return }
        latestReactionID = reaction.id
        phaseGeneration &+= 1
        let generation = phaseGeneration
        apply(phase: reaction.phase, generation: generation)
    }

    private func apply(phase: CombatantAttackPhase, generation: Int) {
        let recipe = CombatFeedbackAttackRecipes.cardAttack(for: .attack)
        switch phase {
        case .windUp:
            withAnimation(.smooth(duration: recipe.windUpDuration)) {
                pose = recipe.windUpPose(aim: aim)
            }
        case .swing:
            runSwingThenRecover(recipe: recipe, generation: generation)
        case .cancel:
            withAnimation(.bouncy(duration: recipe.recoverDuration)) {
                pose = recipe.restPose
            }
        case .full:
            withAnimation(.smooth(duration: recipe.windUpDuration)) {
                pose = recipe.windUpPose(aim: aim)
            } completion: {
                guard generation == phaseGeneration else { return }
                runSwingThenRecover(recipe: recipe, generation: generation)
            }
        }
    }

    private func runSwingThenRecover(
        recipe: CombatantAttackReactionRecipe,
        generation: Int
    ) {
        withAnimation(.snappy(duration: recipe.swingDuration)) {
            pose = recipe.swingPose(aim: aim)
        } completion: {
            guard generation == phaseGeneration else { return }
            withAnimation(.bouncy(duration: recipe.recoverDuration)) {
                pose = recipe.restPose
            }
        }
    }
}
