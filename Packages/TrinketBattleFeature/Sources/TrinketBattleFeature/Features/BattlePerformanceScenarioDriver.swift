import BattleEngine
import SwiftUI
import TrinketBattleRuntime
import TrinketCore
import TrinketDesignSystem
import TrinketFeatureSupport

#if DEBUG

@MainActor
struct BattlePerformanceScenarioDriver {
    let scenario: BattlePerformanceScenario
    let battleSession: BattleSession
    let battleSize: CGSize
    let castPresentation: BattleCastPresentationState

    func perform() -> String? {
        switch scenario {
        case .realCardPlay, .handDragCancel:
            // XCUI supplies the real finger gesture while the harness samples frames.
            nil
        case .engineHand:
            runEngineHand()
        case .engineFeedback:
            runEngineFeedback()
        case .turnTransition:
            runTurnTransition()
        case .combinedWorstCase:
            runCombinedWorstCase()
        }
    }

    private func runEngineHand() -> String? {
        guard let card = playableCard() else {
            return "no-playable-card"
        }
        return battleSession.performEngineCardForPerformance(cardID: card.id)
            ? nil
            : "engine-rejected"
    }

    private func runEngineFeedback() -> String? {
        guard let card = playableCard() else { return "no-playable-card" }
        let outcome = battleSession.playCard(cardID: card.id)
        return outcome.didCommit ? nil : "commit-rejected"
    }

    private func runTurnTransition() -> String? {
        _ = battleSession.endTurn()
        return nil
    }

    private func runCombinedWorstCase() -> String? {
        guard let card = playableCard() else { return "no-playable-card" }
        if let combatantID = battleSession.combatantID(for: card.owner) {
            battleSession.beginAttackWindUp(for: combatantID)
        }
        let outcome = battleSession.playCard(cardID: card.id)
        guard outcome.didCommit else { return "commit-rejected" }
        if let combatantID = battleSession.combatantID(for: card.owner) {
            battleSession.commitAttackSwing(for: combatantID)
        }
        castPresentation.append(activationRequest(for: card))
        return nil
    }

    private func playableCard() -> BattleCard? {
        battleSession.hand.first(where: { battleSession.isCardPlayable($0) })
    }

    private func activationRequest(for card: BattleCard) -> CardActivationRequest {
        let size = CGSize(
            width: min(132, battleSize.width * 0.34),
            height: min(184, battleSize.width * 0.47)
        )
        return CardActivationRequest(
            artworkName: card.ability.artReference?.imageName,
            center: CGPoint(x: battleSize.width / 2, y: battleSize.height * 0.78),
            size: size,
            rotation: 0,
            verticalTilt: 0,
            scale: 1,
            keywords: card.ability.keywords
        )
    }

    static func feedbackEvents(in session: BattleSession) -> [ActionEvent] {
        guard let readModel = session.simulation.readModel else { return [] }
        let targets = [readModel.enemy, readModel.hero, readModel.companion]
        let keywords: [Keyword] = [.physical, .burn, .freeze, .holy, .poison, .block]
        return (0 ..< 9).map { index in
            let target = targets[index % targets.count]
            return ActionEvent(
                id: 90000 + index,
                kind: index.isMultiple(of: 3) ? .effect : .abilityDamage,
                effectKind: index.isMultiple(of: 3) ? .shieldApplied : nil,
                actorID: readModel.hero.id,
                actorName: readModel.hero.name,
                abilityID: "performance-feedback",
                abilityName: "Performance Feedback",
                targetID: target.id,
                targetName: target.name,
                amount: 8 + index,
                keyword: keywords[index % keywords.count]
            )
        }
    }
}

@MainActor
func battlePerformancePrimeChipHostPipeline(
    scenario: BattlePerformanceScenario,
    battleSession: BattleSession
) async {
    guard scenario != .handDragCancel, scenario != .engineHand else { return }
    let date = Date.now
    battleSession.feedback.record(
        BattlePerformanceScenarioDriver.feedbackEvents(in: battleSession),
        at: date
    )
    try? await Task.sleep(for: .milliseconds(200))
    battleSession.feedback.clear()
    CombatFeedbackChipBridge.publish(.reset)
    try? await Task.sleep(for: .milliseconds(50))
}
#endif
