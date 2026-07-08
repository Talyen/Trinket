import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleSimulatorTests {
    private var defaultEnemy: Combatant { GameContent.enemies.first!.combatant }
    private var wolfPet: Combatant { GameContent.pets.first { $0.id == "wolf" }! }

    @Test func summaryComputesWinRateAndAverages() {
        let hero = GameContent.heroes[2]
        let victory = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy)
        let watcher = Combatant(id: "watcher", name: "Watcher", role: .hero, maxHealth: 10, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 10, abilities: [])
        let wall = Combatant(id: "wall", name: "Wall", role: .enemy, maxHealth: 5, abilities: [])
        let tickLimit = BattleSimulator.run(hero: watcher, pet: observer, enemy: wall, maxTicks: 3)

        let summary = BattleSimulationSummary.summarize([victory, tickLimit])

        #expect(summary.runCount == 2)
        #expect(summary.winCount == 1)
        #expect(summary.tickLimitCount == 1)
        #expect(abs((summary.winRate) - (0.5)) < 0.001)
        #expect(summary.averageTickCount > 0)
        #expect(summary.averageActionCount > 0)
    }

    @Test func runBatchProducesMultipleResults() {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy
        )
        let batch = BattleSimulator.runBatch(
            matchups: [matchup],
            options: BattleSimulationOptions(runCount: 3, seed: 42)
        )

        #expect(batch.count == 1)
        #expect(batch[0].results.count == 3)
        #expect(batch[0].summary.runCount == 3)
    }

    @Test func recordsEventsDisabled() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(recordsEvents: false)
        )

        #expect(result.events.isEmpty)
        #expect(!(result.log.isEmpty))
    }

    @Test func recordsLogDisabled() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(recordsLog: false)
        )

        #expect(result.log.isEmpty)
        #expect(!(result.events.isEmpty))
    }

    @Test func zeroMaxTicksReturnsTickLimitImmediately() {
        let hero = GameContent.heroes[2]
        let result = BattleSimulator.run(
            hero: hero,
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(maxTicks: 0)
        )

        #expect(result.outcome == .tickLimit)
        #expect(result.tickCount == 0)
        #expect(result.didHitTickLimit)
    }

    @Test func metricsSplitAbilityAndStatusDamage() {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42)
        )

        #expect(result.metrics.abilityDamage > 0)
        #expect(result.metrics.statusDamage >= 0)
        #expect(
            result.metrics.totalDamage == result.metrics.abilityDamage + result.metrics.statusDamage
        )
    }

    @Test func victoryLogMessage() throws {
        let hero = GameContent.heroes[2]
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        #expect(result.log.contains { $0.text.contains("is defeated.") })
    }

    @Test func defeatLogMessage() {
        let hero = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let pet = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        #expect(result.log.contains { $0.text.contains("Your party has been defeated") })
    }

    @Test func deferredLogRebuildMatchesEagerRebuild() {
        let hero = GameContent.heroes[2]
        let options = BattleSimulationOptions(seed: 42, rebuildLogEachStep: false)
        let deferred = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy, options: options)
        let eager = BattleSimulator.run(
            hero: hero,
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42, rebuildLogEachStep: true)
        )

        #expect(deferred.outcome == eager.outcome)
        #expect(deferred.log.map(\.text) == eager.log.map(\.text))
        #expect(deferred.events.map(\.id) == eager.events.map(\.id))
    }

    @Test func lazyLogSyncMatchesTrackedLog() {
        var battle = BattleState(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            rngSeed: 42,
            tracksLog: false
        )

        while !battle.isBattleOver {
            _ = battle.advanceOneStep(rebuildLog: false)
        }

        #expect(battle.log.isEmpty)

        battle.syncLog()

        let tracked = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42, recordsLog: true, rebuildLogEachStep: true)
        )

        #expect(battle.log.map(\.text) == tracked.log.map(\.text))
    }
}
