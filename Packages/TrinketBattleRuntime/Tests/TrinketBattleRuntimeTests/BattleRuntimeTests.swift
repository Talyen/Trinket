import BattleEngine
import Testing
import TrinketContent
@testable import TrinketBattleRuntime

@Suite("Battle runtime contract")
@MainActor
struct BattleRuntimeTests {
    @Test("the fallback store activates a matching prepared run")
    func activatesMatchingPreparedRun() {
        let runtime = BattleRuntimeStore()
        let configuration = makeConfiguration(runKey: BattleRunKey("journey:stage-1"))

        #expect(runtime.lifecyclePhase == .idle)
        #expect(runtime.prepareBattleRun(configuration))
        #expect(runtime.lifecyclePhase == .prepared)

        #expect(
            runtime.activatePreparedBattle(
                runKey: BattleRunKey("journey:stage-1"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle?.id == configuration.id)
        #expect(runtime.lifecyclePhase == .active)
    }

    @Test("direct activation and restart are the only active-run transitions")
    func ownsActivationAndRestartTransitions() {
        let runtime = BattleRuntimeStore()
        let first = makeConfiguration(runKey: BattleRunKey("journey:stage-1"))
        let second = makeConfiguration(runKey: BattleRunKey("journey:stage-2"))

        #expect(runtime.activate(first))
        #expect(runtime.activeBattle?.id == first.id)
        #expect(!runtime.activate(second))
        #expect(runtime.activeBattle?.id == first.id)
        #expect(runtime.restart(second))
        #expect(runtime.activeBattle?.id == second.id)
        #expect(runtime.lifecyclePhase == .active)

        runtime.endBattle()
        #expect(runtime.lifecyclePhase == .idle)
        #expect(!runtime.restart(first))
    }

    @Test("a mismatched run cannot activate")
    func rejectsMismatchedPreparedRun() {
        let runtime = BattleRuntimeStore()
        runtime.prepareBattleRun(makeConfiguration(runKey: BattleRunKey("journey:stage-1")))

        #expect(
            !runtime.activatePreparedBattle(
                runKey: BattleRunKey("journey:stage-2"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle == nil)
        #expect(runtime.hasPreparedRun(BattleRunKey("journey:stage-1")))
    }

    @Test("a prepared run does not activate while another battle is active")
    func rejectsPreparedActivationWhileActive() {
        let runtime = BattleRuntimeStore()
        let first = makeConfiguration(runKey: BattleRunKey("labyrinth:first"))
        let sibling = makeConfiguration(runKey: BattleRunKey("labyrinth:sibling"))

        #expect(runtime.prepareBattleRun(first))
        #expect(runtime.prepareBattleRun(sibling))
        #expect(
            runtime.activatePreparedBattle(
                runKey: BattleRunKey("labyrinth:first"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(
            !runtime.activatePreparedBattle(
                runKey: BattleRunKey("labyrinth:sibling"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle?.id == first.id)
        #expect(runtime.hasPreparedRun(BattleRunKey("labyrinth:sibling")))
    }

    @Test("activating one prepared run leaves sibling prepares intact")
    func activatePreparedBattleKeepsSiblingRuns() {
        let runtime = BattleRuntimeStore()
        let kept = makeConfiguration(runKey: BattleRunKey("labyrinth:keep"))
        let sibling = makeConfiguration(runKey: BattleRunKey("labyrinth:sibling"))

        #expect(runtime.prepareBattleRun(kept))
        #expect(runtime.prepareBattleRun(sibling))
        #expect(
            runtime.activatePreparedBattle(
                runKey: BattleRunKey("labyrinth:keep"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle?.id == kept.id)
        #expect(runtime.hasPreparedRun(BattleRunKey("labyrinth:sibling")))
        #expect(!runtime.hasPreparedRun(BattleRunKey("labyrinth:keep")))
    }

    @Test("a mismatched party or enemy id cannot activate")
    func rejectsPreparedRunWithMismatchedIDs() {
        let runtime = BattleRuntimeStore()
        let runKey = BattleRunKey("journey:stage-1")
        runtime.prepareBattleRun(makeConfiguration(runKey: runKey))

        #expect(
            !runtime.activatePreparedBattle(
                runKey: runKey,
                heroID: "other-hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle == nil)
        #expect(runtime.hasPreparedRun(runKey))
    }

    @Test("scene suspension and end-of-run lifecycle are owned by the runtime")
    func ownsLifecycleState() {
        let runtime = BattleRuntimeStore()

        runtime.setSuspendedForScenePhase(true)
        #expect(runtime.isSuspendedForScenePhase)

        runtime.setSuspendedForScenePhase(false)
        runtime.endBattle()
        #expect(!runtime.isSuspendedForScenePhase)
        #expect(runtime.activeBattle == nil)
        #expect(runtime.lifecyclePhase == .idle)
    }

    @Test("preparing the same configuration id does not replace a prepared run")
    func prepareBattleRunKeepsMatchingConfiguration() {
        let runtime = BattleRuntimeStore()
        let runKey = BattleRunKey("journey:stage-1")
        let configuration = makeConfiguration(runKey: runKey)

        #expect(runtime.prepareBattleRun(configuration))
        #expect(runtime.prepareBattleRun(configuration))
        #expect(
            runtime.activatePreparedBattle(
                runKey: runKey,
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle?.id == configuration.id)
    }

    @Test("preparing a different configuration id replaces a prepared run")
    func prepareBattleRunReplacesDifferentConfiguration() {
        let runtime = BattleRuntimeStore()
        let runKey = BattleRunKey("journey:stage-1")
        let original = makeConfiguration(runKey: runKey)
        let replacement = makeConfiguration(runKey: runKey, rngSeed: 99)

        #expect(runtime.prepareBattleRun(original))
        #expect(runtime.prepareBattleRun(replacement))
        #expect(
            runtime.activatePreparedBattle(
                runKey: runKey,
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle?.id == replacement.id)
        #expect(runtime.activeBattle?.id != original.id)
    }

    @Test("keepPreparedRuns drops stale prepared configurations")
    func keepPreparedRunsDropsStaleConfigurations() {
        let runtime = BattleRuntimeStore()
        let kept = makeConfiguration(runKey: BattleRunKey("labyrinth:keep"))
        let dropped = makeConfiguration(runKey: BattleRunKey("labyrinth:drop"))

        #expect(runtime.prepareBattleRun(kept))
        #expect(runtime.prepareBattleRun(dropped))

        runtime.keepPreparedRuns([BattleRunKey("labyrinth:keep")])

        #expect(runtime.hasPreparedRun(BattleRunKey("labyrinth:keep")))
        #expect(!runtime.hasPreparedRun(BattleRunKey("labyrinth:drop")))

        #expect(
            !runtime.activatePreparedBattle(
                runKey: BattleRunKey("labyrinth:drop"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(
            runtime.activatePreparedBattle(
                runKey: BattleRunKey("labyrinth:keep"),
                heroID: "hero",
                companionID: "companion",
                enemyID: "enemy"
            )
        )
        #expect(runtime.activeBattle?.id == kept.id)
    }

    private func makeConfiguration(runKey: BattleRunKey, rngSeed: UInt64 = 42) -> BattleRunConfiguration {
        BattleRunConfiguration(
            runKey: runKey,
            rngSeed: rngSeed,
            hero: makeMember(id: "hero", role: .hero),
            companion: makeMember(id: "companion", role: .companion),
            enemy: Combatant(
                id: "enemy",
                name: "Enemy",
                role: .enemy,
                maxHealth: 10,
                abilities: []
            ),
            enemyModifiers: .zero
        )
    }

    private func makeMember(
        id: String,
        role: Combatant.Role
    ) -> BattleRunConfiguration.PartyMember {
        BattleRunConfiguration.PartyMember(
            combatant: Combatant(
                id: id,
                name: id,
                role: role,
                maxHealth: 10,
                abilities: []
            ),
            progression: .initial,
            equipmentLoadout: EquipmentLoadout(),
            modifiers: .zero
        )
    }
}
