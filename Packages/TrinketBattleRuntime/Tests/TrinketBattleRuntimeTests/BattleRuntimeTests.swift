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

    private func makeConfiguration(runKey: BattleRunKey) -> BattleRunConfiguration {
        BattleRunConfiguration(
            runKey: runKey,
            rngSeed: 42,
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
