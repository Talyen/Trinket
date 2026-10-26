import TrinketContent
import TrinketCore

package enum EffectHandlers {
    /// Stored effects have a shared countdown unless their rules own the tick.
    package static func advanceTurn(_ active: ActiveEffect, on target: Combatant, in context: inout BattleState) async {
        switch active.effect.kind {
        case .burn, .poison: await advanceDecayingDoT(active, on: target, in: &context)
        case .bleed: await advanceBleed(active, on: target, in: &context)
        case .controlMeter: advanceControlMeter(active, on: target, in: &context)
        case .recurringDamage: await advanceRecurringDamage(active, on: target, in: &context)
        case .avatar: await advanceAvatar(active, on: target, in: &context)
        case .deathsDoor: await advanceDeathsDoor(active, on: target, in: &context)
        default:
            guard active.effect.advancesEachTurn else { return }
            var updated = active
            updated.remainingTurns -= 1
            ActiveEffectMutation.finishTurn(active, replacement: updated.remainingTurns > 0 ? updated : nil, on: target, in: &context)
        }
    }

    package static func summary(for stacks: [ActiveEffect], keyword: Keyword) -> EffectSummary? {
        switch stacks.first?.effect.kind {
        case .burn, .poison: summarizeDecayingDoT(for: stacks, keyword: keyword)
        case .bleed: summarizeBleed(for: stacks, keyword: keyword)
        case .controlMeter: summarizeControlMeter(for: stacks, keyword: keyword)
        case .shield: summarizeBlockBuff(for: stacks, keyword: keyword)
        case .deathsDoor: summarizeDeathsDoor(for: stacks, keyword: keyword)
        case .thorns, .nextBurnBonus: summarizeStackingAmountBuff(for: stacks, keyword: keyword)
        case .marked, .criticalChanceBonus, .restoreManaOnHit, .damageKeywordOverride, .onHitDamage, .hemorrhage,
             .nextHolyStrike, .nextStrikeDouble, .playNextCardTwice, .evadeNextHit, .nextStrikeCritical,
             .nextStrikeLeech, .nextStrikeDamageKeywordOverride, .freezeNextAttacker: summarizeStoredEffect(for: stacks, keyword: keyword)
        case .maximumManaBonus: summarizeMaximumManaBonus(for: stacks, keyword: keyword)
        case .recurringDamage: summarizeRecurringDamage(for: stacks, keyword: keyword)
        case .avatar: summarizeAvatar(for: stacks, keyword: keyword)
        case .damageReductionPercent, .damageReductionFlat, .healingReductionPercent: summarizeTimedDebuff(for: stacks, keyword: keyword)
        default: nil
        }
    }
}
