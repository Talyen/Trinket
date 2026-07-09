import Testing
import BattleEngine
import TrinketCore
import TrinketContent

@Suite
struct BattleSimulatorTests {
    private var defaultEnemy: Combatant { GameContent.enemies.first!.combatant }
    private var wolfPet: Combatant { GameContent.pets.first { $0.id == "wolf" }! }

    @Test func summaryComputesWinRateAndAverages() throws {
        let hero = GameContent.heroes[2]
        let victory = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy)
        let watcher = Combatant(id: "watcher", name: "Watcher", role: .hero, maxHealth: 10, abilities: [])
        let observer = Combatant(id: "observer", name: "Observer", role: .pet, maxHealth: 10, abilities: [])
        let wall = Combatant(id: "wall", name: "Wall", role: .enemy, maxHealth: 5, abilities: [])
        let tickLimit = BattleSimulator.run(hero: watcher, pet: observer, enemy: wall, maxTicks: 3)

        let summary = BattleSimulationSummary.summarize([victory, tickLimit])

        try #expect(summary.runCount == 2)
        try #expect(summary.winCount == 1)
        try #expect(summary.tickLimitCount == 1)
        try #expect(abs((summary.winRate) - (0.5)) < 0.001)
        try #expect(summary.averageTickCount > 0)
        try #expect(summary.averageActionCount > 0)
    }

    @Test func runBatchProducesMultipleResults() throws {
        let matchup = BattleMatchup(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy
        )
        let batch = BattleSimulator.runBatch(
            matchups: [matchup],
            options: BattleSimulationOptions(runCount: 3, seed: 42)
        )

        try #expect(batch.count == 1)
        try #expect(batch[0].results.count == 3)
        try #expect(batch[0].summary.runCount == 3)
    }

    @Test func recordsEventsDisabled() throws {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(recordsEvents: false)
        )

        try #expect(result.events.isEmpty)
        try #expect(!(result.log.isEmpty))
    }

    @Test func recordsLogDisabled() throws {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(recordsLog: false)
        )

        try #expect(result.log.isEmpty)
        try #expect(!(result.events.isEmpty))
    }

    @Test func zeroMaxTicksReturnsTickLimitImmediately() throws {
        let hero = GameContent.heroes[2]
        let result = BattleSimulator.run(
            hero: hero,
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(maxTicks: 0)
        )

        try #expect(result.outcome == .tickLimit)
        try #expect(result.tickCount == 0)
        try #expect(result.didHitTickLimit)
    }

    @Test func metricsSplitAbilityAndStatusDamage() throws {
        let result = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42)
        )

        try #expect(result.metrics.abilityDamage > 0)
        try #expect(result.metrics.statusDamage >= 0)
        try #expect(
            result.metrics.totalDamage == result.metrics.abilityDamage + result.metrics.statusDamage
        )
    }

    @Test func victoryLogMessage() throws {
        let hero = GameContent.heroes[2]
        let pet = try #require(GameContent.pets.first { $0.id == "wolf" })
        let enemy = try #require(GameContent.enemies.first?.combatant)
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        try #expect(result.log.contains { $0.text.contains("is defeated.") })
    }

    @Test func defeatLogMessage() throws {
        let hero = Combatant(id: "fragile", name: "Fragile", role: .hero, maxHealth: 1, abilities: [])
        let pet = Combatant(id: "helper", name: "Helper", role: .pet, maxHealth: 1, abilities: [])
        let enemy = Combatant(id: "strong", name: "Strong", role: .enemy, maxHealth: 100, abilities: [.slash])
        let result = BattleSimulator.run(hero: hero, pet: pet, enemy: enemy)

        try #expect(result.log.contains { $0.text.contains("Your party has been defeated") })
    }

    @Test func deferredLogRebuildMatchesEagerRebuild() throws {
        let hero = GameContent.heroes[2]
        let options = BattleSimulationOptions(seed: 42, rebuildLogEachStep: false)
        let deferred = BattleSimulator.run(hero: hero, pet: wolfPet, enemy: defaultEnemy, options: options)
        let eager = BattleSimulator.run(
            hero: hero,
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42, rebuildLogEachStep: true)
        )

        try #expect(deferred.outcome == eager.outcome)
        try #expect(deferred.log.map(\.text) == eager.log.map(\.text))
        try #expect(deferred.events.map(\.id) == eager.events.map(\.id))
    }

    @Test func lazyLogSyncMatchesTrackedLog() throws {
        // Scope the untracked battle so its large value-type state is released
        // before the second simulation — cooperative Swift Testing threads have
        // a small stack and overflow when two full BattleStates stay live.
        let lazyLogTexts: [String] = {
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

            precondition(battle.log.isEmpty)
            battle.syncLog()
            return battle.log.map(\.text)
        }()

        let tracked = BattleSimulator.run(
            hero: GameContent.heroes[2],
            pet: wolfPet,
            enemy: defaultEnemy,
            options: BattleSimulationOptions(seed: 42, recordsLog: true, rebuildLogEachStep: true)
        )

        try #expect(lazyLogTexts == tracked.log.map(\.text))
    }
}
