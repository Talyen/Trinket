import BattleEngine
import Testing
import TrinketContent
import TrinketCore

struct BattleOutcomeResolverTests {
    @Test func simultaneousDefeatResolvesAsVictory() throws {
        try #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: true) == .victory
        )
    }

    @Test func partyDefeatResolvesAsDefeat() throws {
        try #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: false) == .defeat
        )
    }

    @Test func enemyDefeatResolvesAsVictory() throws {
        try #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: false, isEnemyDefeated: true) == .victory
        )
    }

    @Test func ongoingBattleReturnsNil() throws {
        try #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: false, isEnemyDefeated: false) == nil
        )
    }
}
