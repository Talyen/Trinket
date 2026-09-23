import TrinketContent
import TrinketCore

package extension CombatTriggerEngine {
    static func preparePantherRedline(afterHealthLoss target: Combatant, in context: inout BattleState) {
        guard context.modifiers(for: target.id).triggers.belowHalfHealthNextBleedDouble,
              context.roster.health(for: target) > 0,
              context.roster.health(for: target) * 2 < context.roster.maxHealth(for: target),
              context.roster.runtime(for: target)?.talents.battle.wasBelowHalfHealth == false
        else { return }
        let preparedCardSerial = context.resolution.cardTalents?.playSerial
        context.roster.mutateRuntime(for: target) {
            $0.talents.battle.wasBelowHalfHealth = true
            $0.talents.pending.doubleNextBleedAttack = true
            $0.talents.pending.nextBleedAttackPreparedCardSerial = preparedCardSerial
        }
    }

    static func resetPantherRedline(afterHealthRestoration target: Combatant, in context: inout BattleState) {
        guard context.modifiers(for: target.id).triggers.belowHalfHealthNextBleedDouble,
              context.roster.health(for: target) * 2 >= context.roster.maxHealth(for: target)
        else { return }
        context.roster.mutateRuntime(for: target) { $0.talents.battle.wasBelowHalfHealth = false }
    }
}
