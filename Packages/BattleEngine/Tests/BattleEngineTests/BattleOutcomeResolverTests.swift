import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleOutcomeResolverTests {
    private static let cases: [(Bool, Bool, BattleSimulationOutcome?)] = [
        (true, true, .victory),
        (true, false, .defeat),
        (false, true, .victory),
        (false, false, nil)
    ]

    @Test(arguments: cases)
    func resolvesPartyAndEnemyDefeatCombinations(
        isPartyDefeated: Bool,
        isEnemyDefeated: Bool,
        expected: BattleSimulationOutcome?
    ) throws {
        try #expect(
            BattleSimulationOutcome.resolve(
                isPartyDefeated: isPartyDefeated,
                isEnemyDefeated: isEnemyDefeated
            ) == expected
        )
    }
}
