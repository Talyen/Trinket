import Testing
@testable import TrinketBattleFeature

struct CombatMotionRecipeTests {
    @Test func `hit phases retain shipping transforms and independent lifetimes`() {
        let expected: [(CombatantHitReactionKind, CombatantPose, Double, Double, Double)] = [
            (.none, .rest, 0.01, 0.16, 0.01),
            (.damage, .init(scaleX: 0.945, scaleY: 1.035, offsetX: -6), 0.08, 0.16, 0.24),
            (.critical, .init(scaleX: 0.91, scaleY: 1.055, offsetX: -9), 0.08, 0.18, 0.26),
            (.block, .init(scaleX: 0.945, scaleY: 1.035, offsetX: -6), 0.08, 0.16, 0.24),
            (.heal, .init(scaleX: 1.02, scaleY: 1.02), 0.1, 0.16, 0.26),
            (.dodge, .init(offsetX: 6), 0.08, 0.16, 0.24),
            (.celebrate, .init(scaleX: 1.1, scaleY: 0.86, offsetY: -8), 0.1, 0.22, 1.0),
        ]
        for (kind, pose, impact, recovery, lifetime) in expected {
            let recipe = CombatFeedbackCardRecipes.cardReaction(for: kind)
            #expect(recipe.kind == kind)
            #expect(recipe.impact.pose == pose)
            #expect(recipe.impact.duration == impact)
            #expect(recipe.recovery.pose == .rest)
            #expect(recipe.recovery.duration == recovery)
            #expect(recipe.duration == lifetime)
            if kind == .celebrate {
                #expect(recipe.rotation.map(\.value) == [-6, 6, -6, 6, -5, 5, -4, 4, -2, 0])
                #expect(recipe.rotation.allSatisfy { $0.duration == 0.1 })
            } else {
                #expect(recipe.rotation.isEmpty)
            }
        }
    }

    @Test func `attack phases retain aim and shipping timing`() {
        let recipe = CombatFeedbackAttackRecipes.lungeCardAttack
        #expect(recipe.windUp.pose == .init(scaleX: 0.98, scaleY: 1.02, offsetY: -12, rotation: -4))
        #expect(recipe.swing.pose == .init(scaleX: 1.05, scaleY: 0.94, offsetY: 28, rotation: 3))
        #expect(recipe.recovery.pose == .rest)
        #expect(recipe.windUp.duration == 0.40)
        #expect(recipe.swing.duration == 0.15)
        #expect(recipe.recovery.duration == 0.45)
        #expect(recipe.windUp.pose.aimed(.towardEnemy).offsetY == 12)
        #expect(recipe.windUp.pose.aimed(.towardParty).offsetY == -12)
    }
}
