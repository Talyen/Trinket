import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleOutcomeResolverTests {
    @Test(arguments: [
        (true, true, Optional(BattleSimulationOutcome.victory)),
        (true, false, Optional(.defeat)),
        (false, true, Optional(.victory)),
        (false, false, nil)
    ] as [(Bool, Bool, BattleSimulationOutcome?)])
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
