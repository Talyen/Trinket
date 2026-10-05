import Testing
import TrinketContent
import TrinketCore
@testable import BattleEngine

struct ControlExtensionLifecycleTests {
    @Test(arguments: [Keyword.stun, .freeze])
    func `cleansed extended control does not extend a later ordinary status`(keyword: Keyword) {
        var battle = extendedControlBattle()
        applyControl(keyword, source: battle.hero, in: &battle)
        _ = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(keyword), source: battle.companion, target: battle.enemy, abilityName: "Cleanse", in: &battle,
        ) }
        applyControl(keyword, source: battle.companion, in: &battle)

        _ = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }

        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy))
        #expect(!CombatTriggerEngine.consumeEnemyActionDelay(in: &battle).cancelled)
    }

    @Test func `cleanse removes only its own control extension and preserves independent delay`() {
        var battle = extendedControlBattle()
        applyControl(.freeze, source: battle.hero, in: &battle)
        applyControl(.stun, source: battle.hero, in: &battle)
        battle.additionalControlSkipsByCombatantID[battle.enemy.id] = 1
        _ = CombatExecutor.run { await EffectRemovalOperation.resolveCleanse(
            .all(.freeze), source: battle.companion, target: battle.enemy, abilityName: "Cleanse", in: &battle,
        ) }

        #expect(CombatTriggerEngine.consumeEnemyActionDelay(in: &battle).cancelled)
        #expect(!CombatTriggerEngine.consumeEnemyActionDelay(in: &battle).cancelled)
        _ = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
        _ = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy))
    }

    @Test func `subzero mist and searing bind keep their own extra skipped actions`() throws {
        let knight = try BattleTestFixtures.catalogBuild(combatantID: "knight", talents: "knight_stun_t3_1")
        let moth = try BattleTestFixtures.catalogBuild(combatantID: "mana_moth", talents: "mana_moth_freeze_t2_2")
        var mothModifiers = moth.modifiers
        #expect(mothModifiers.triggers.freezeExtendChancePercent > 0)
        // Force Subzero Mist's rare proc so the duration interaction is deterministic.
        mothModifiers.triggers.freezeExtendChancePercent = 1
        var battle = BattleStateTestFactory.makeBattle(
            hero: knight.combatant, companion: moth.combatant,
            heroModifiers: knight.modifiers, companionModifiers: mothModifiers, dealOpeningHand: false,
        )
        battle.appendEffect(.burn(1), to: battle.enemy, sourceID: battle.hero.id, remainingTurns: 0)
        applyControl(.freeze, source: battle.companion, in: &battle)
        applyControl(.stun, source: battle.hero, in: &battle)

        for _ in 0 ..< 2 {
            let events = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
            #expect(events.first?.keyword == .freeze)
        }
        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .freeze))
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))

        let firstStunSkip = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
        #expect(firstStunSkip.first?.keyword == .stun)
        #expect(battle.roster.hasPendingActionSkip(for: battle.enemy, keyword: .stun))
        let finalStunSkip = CombatExecutor.run { await BattleTurnEngine.consumeActionSkip(for: battle.enemy, context: &battle) }
        #expect(finalStunSkip.first?.keyword == .stun)
        #expect(!battle.roster.hasPendingActionSkip(for: battle.enemy))
    }

    private func extendedControlBattle() -> BattleState {
        BattleTestFixtures.makePipelineContext(
            heroModifiers: .init(triggers: CombatTraitTriggers(
                control: ControlTriggers(freezeExtendChancePercent: 1, stunExtendChancePercent: 1),
            )),
        )
    }

    private func applyControl(_ keyword: Keyword, source: Combatant, in battle: inout BattleState) {
        _ = CombatExecutor.run { await ControlMeterEngine.applyMeterCharge(
            100, keyword: keyword, to: battle.enemy, sourceActorID: source.id,
            applyFightPacing: false, in: &battle,
        ) }
    }
}
