import BattleEngine
import Testing

struct BattleOutcomeResolverTests {
    private static let cases: [(Bool, Bool, BattleSimulationOutcome?)] = [
        (true, true, .defeat),
        (true, false, .defeat),
        (false, true, .victory),
        (false, false, nil),
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
