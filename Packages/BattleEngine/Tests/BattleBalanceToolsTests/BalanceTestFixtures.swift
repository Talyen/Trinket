import BattleEngine
@testable import BattleBalanceTools

/// These report fixtures avoid catalog loading and combat. Tests supply only the
/// fields relevant to the statistic, replay, or rendering requirement they exercise.
enum BalanceTestFixtures {
    static func result(
        outcome: BattleSimulationOutcome = .victory,
        rounds: Int = 6,
        actions: Int = 10,
        timedOut: Bool = false,
        partyHPRemainingFraction: Double = 0.5,
        enemyHPRemainingFraction: Double = 0,
    ) -> BattleSimResult {
        BattleSimResult(
            outcome: outcome, rounds: rounds, actions: actions, timedOut: timedOut,
            partyHPRemainingFraction: partyHPRemainingFraction, enemyHPRemainingFraction: enemyHPRemainingFraction,
        )
    }

    static func step(
        id: String = "test-step",
        mode: SimulationGameMode = .campaign,
        containerID: String = "chapter-1",
        containerTitle: String = "Chapter 1",
        stepIndex: Int = 1,
        displayTitle: String = "Stage 1-1",
        enemyID: String = "goblin",
        enemyLevel: Int = 5,
        isBoss: Bool = false,
    ) -> ModeProgressionStep {
        ModeProgressionStep(
            id: id, mode: mode, containerID: containerID, containerTitle: containerTitle,
            stepIndex: stepIndex, displayTitle: displayTitle, enemyID: enemyID, enemyLevel: enemyLevel, isBoss: isBoss,
        )
    }
}
