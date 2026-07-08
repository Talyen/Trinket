import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleOutcomeResolverTests {
    @Test func simultaneousDefeatResolvesAsVictory() {
        #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: true) == .victory
        )
    }

    @Test func partyDefeatResolvesAsDefeat() {
        #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: true, isEnemyDefeated: false) == .defeat
        )
    }

    @Test func enemyDefeatResolvesAsVictory() {
        #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: false, isEnemyDefeated: true) == .victory
        )
    }

    @Test func ongoingBattleReturnsNil() {
        #expect(
            BattleSimulationOutcome.resolve(isPartyDefeated: false, isEnemyDefeated: false) == nil
        )
    }
}
