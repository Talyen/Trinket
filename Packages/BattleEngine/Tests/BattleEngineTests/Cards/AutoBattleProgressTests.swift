import Testing
import TrinketContentTestSupport
@testable import BattleEngine

struct AutoBattleProgressTests {
    @Test func `progress survives healing within a command and expires only after thirty quiet rounds`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(enemy: CombatantFixtures.passiveEnemy(maxHealth: 100))
        var progress = AutoBattleProgress(in: battle)
        battle.turnCount = 1
        battle.roster.enemy.currentHealth = 50
        battle.roster.enemy.currentHealth = 100
        var paused = progress.shouldPause(in: battle)
        #expect(!paused)
        battle.turnCount = 30
        paused = progress.shouldPause(in: battle)
        #expect(!paused)
        battle.turnCount = 31
        paused = progress.shouldPause(in: battle)
        #expect(paused)
        battle.roster.enemy.currentHealth = 51
        paused = progress.shouldPause(in: battle)
        #expect(paused)
        battle.roster.enemy.currentHealth = 49
        paused = progress.shouldPause(in: battle)
        #expect(!paused)
        battle.turnCount = 60
        paused = progress.shouldPause(in: battle)
        #expect(!paused)
        battle.turnCount = 61
        paused = progress.shouldPause(in: battle)
        #expect(paused)
        var resumed = AutoBattleProgress(in: battle)
        let resumedPause = resumed.shouldPause(in: battle)
        #expect(!resumedPause)
        #expect(!battle.isBattleOver)
    }

    @Test func `even one Health of progress allows a long battle to continue`() {
        var battle = BattleStateTestFactory.makeMinimalBattle(enemy: CombatantFixtures.passiveEnemy(maxHealth: Int.max))
        var progress = AutoBattleProgress(in: battle)
        for round in 1 ... 300 {
            battle.turnCount = round
            if round.isMultiple(of: 29) {
                battle.roster.enemy.currentHealth -= 1
            }
            let paused = progress.shouldPause(in: battle)
            #expect(!paused)
        }
    }
}
