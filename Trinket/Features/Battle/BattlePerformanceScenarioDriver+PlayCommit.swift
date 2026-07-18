#if DEBUG
import BattleEngine
import CoreGraphics
import SwiftUI
import TrinketCore
import TrinketDesignSystem

extension BattlePerformanceScenarioDriver {
    func runRealCardPlay() async {
        guard let card = battleSession.hand.first(where: { battleSession.isCardPlayable($0) })
            ?? battleSession.hand.first
        else { return }
        // Match finger play: lift through wind-up / armed pose, then commit via
        // production `beginPlay` (hand remove + feedback + cast + attack swing).
        let playLift = -(BattleHandLayout.playDragThreshold + 40)
        for step in 0 ..< 12 {
            guard !Task.isCancelled else { return }
            let progress = Double(step + 1) / 12.0
            forcedDrag.set(
                cardID: card.id,
                translation: CGSize(width: 0, height: playLift * progress)
            )
            try? await Task.sleep(for: .milliseconds(16))
        }
        // Hold one frame armed so wind-up / held visuals settle before commit.
        try? await Task.sleep(for: .milliseconds(16))
        guard !Task.isCancelled else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.cardCommit,
            detail: "scenario=\(scenario.rawValue) card=\(card.id) ability=\(card.ability.id) path=forced-release"
        )
        if scenario == .playRealNoFeedback {
            battleSession.performanceSuppressFeedbackPresentation = true
        }
        forcedDrag.requestPlay()
        // Allow SwiftUI to deliver the commit onChange and clear forced drag.
        try? await Task.sleep(for: .milliseconds(32))
        battleSession.performanceSuppressFeedbackPresentation = false
        if forcedDrag.cardID == card.id {
            forcedDrag.clear()
        }
    }

    func runPlayEngineHand() {
        guard let card = battleSession.hand.first(where: { battleSession.isCardPlayable($0) })
            ?? battleSession.hand.first
        else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.cardCommit,
            detail: "scenario=\(scenario.rawValue) card=\(card.id) path=engine-hand"
        )
        battleSession.performanceSuppressFeedbackPresentation = true
        defer { battleSession.performanceSuppressFeedbackPresentation = false }
        _ = battleSession.playCard(
            cardID: card.id,
            journey: appState.journey,
            homestead: appState.homestead
        )
    }

    func runPlaySwingOnly() {
        guard let card = battleSession.hand.first,
              let combatantID = battleSession.combatantID(for: card.owner)
        else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.cardCommit,
            detail: "scenario=\(scenario.rawValue) combatant=\(combatantID) path=swing-only"
        )
        battleSession.beginAttackWindUp(for: combatantID)
        battleSession.commitAttackSwing(for: combatantID)
    }

    func runPlayStack(for scenario: BattlePerformanceScenario) {
        switch scenario {
        case .playStackDirect:
            runPlayStack(includeFeedback: true, includeCast: true, includeSwing: true)
        case .playStackNoSwing:
            runPlayStack(includeFeedback: true, includeCast: true, includeSwing: false)
        case .playStackNoFeedback:
            runPlayStack(includeFeedback: false, includeCast: true, includeSwing: true)
        case .playStackNoCast:
            runPlayStack(includeFeedback: true, includeCast: false, includeSwing: true)
        default:
            return
        }
    }

    /// Production BattleView.playCard payload without forced-drag release / held transforms.
    func runPlayStack(
        includeFeedback: Bool,
        includeCast: Bool,
        includeSwing: Bool
    ) {
        guard let card = battleSession.hand.first(where: { battleSession.isCardPlayable($0) })
            ?? battleSession.hand.first
        else { return }
        let combatantID = battleSession.combatantID(for: card.owner)
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.cardCommit,
            detail: "scenario=\(scenario.rawValue) card=\(card.id) path=stack-direct"
        )
        if includeSwing, let combatantID {
            battleSession.beginAttackWindUp(for: combatantID)
        }
        if !includeFeedback {
            battleSession.performanceSuppressFeedbackPresentation = true
        }
        defer { battleSession.performanceSuppressFeedbackPresentation = false }
        _ = battleSession.playCard(
            cardID: card.id,
            journey: appState.journey,
            homestead: appState.homestead
        )
        if includeSwing, let combatantID {
            battleSession.commitAttackSwing(for: combatantID)
        }
        if includeCast {
            // Card is already removed from hand — rebuild cast from the played ability.
            castPresentation.append(CardActivationRequest(
                artworkName: card.ability.artReference?.imageName,
                center: CGPoint(x: battleSize.width / 2, y: battleSize.height * 0.78),
                size: CGSize(
                    width: min(132, battleSize.width * 0.34),
                    height: min(184, battleSize.width * 0.47)
                ),
                rotation: 0,
                verticalTilt: 0,
                scale: 1,
                keywords: card.ability.keywords
            ))
        }
    }

    func appendCast(
        enforceProductionCap: Bool = true,
        workload: CardCastWorkload = .full,
        particleCount: Int = TrinketMotion.Battle.cardCastParticleCount,
        heldPose: Bool = false
    ) {
        guard let card = battleSession.hand.first else { return }
        BattleFramePacingSignposts.event(
            BattleFramePacingSignposts.Name.cardCommit,
            detail: "scenario=\(scenario.rawValue) card=\(card.id) ability=\(card.ability.id)"
        )
        let size = CGSize(
            width: min(132, battleSize.width * 0.34),
            height: min(184, battleSize.width * 0.47)
        )
        castPresentation.append(CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(x: battleSize.width / 2, y: battleSize.height * 0.78),
            size: size,
            rotation: heldPose ? 0.12 : 0,
            verticalTilt: heldPose ? 18 : 0,
            scale: heldPose ? 1.08 : 1,
            perspective: 0.35,
            keywords: card.ability.keywords,
            particleCount: particleCount,
            workload: workload
        ), enforceProductionCap: enforceProductionCap)
    }
}
#endif
