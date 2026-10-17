import TrinketContent
import TrinketCore

package enum BlockAmountBasis {
    case base, resolved
}

package extension BattleState {
    mutating func consumeNextEffectID() -> Int {
        let id = nextEffectID
        nextEffectID += 1
        return id
    }

    @discardableResult
    mutating func applyBlockGain(
        _ amount: Int,
        to target: Combatant,
        source: Combatant,
        abilityID: String = "",
        abilityName: String,
        amountBasis: BlockAmountBasis = .base,
        origin: ActionEvent.Origin = .automatic,
    ) -> Int {
        guard amount > 0, roster.health(for: target) > 0 else { return 0 }
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(target, in: self)
            || CombatTriggerEngine.preventsPurgedEffect(.shield(.block, amount), on: target, in: self) {
            return 0
        }
        let profile = modifiers(for: source.id)
        let buffer = amountBasis == .base
            ? CombatRounding.scaled(
                SaturatedArithmetic.saturatingAdd(amount, profile.blockGainedBonus),
                multiplier: 1 + profile.blockGainedPercent,
            ) : amount
        let (adjustedBuffer, spendsPreparation) = amountBasis == .base
            ? adjustedBlockGain(buffer, to: target) : (buffer, false)
        let applied = DefensePoolEngine.add(
            adjustedBuffer,
            to: target,
            keyword: .block,
            sourceActorID: source.id,
            applyFightPacing: amountBasis == .base,
            in: &self,
        )
        guard applied > 0 else { return 0 }
        if spendsPreparation {
            roster.mutateRuntime(for: target) {
                $0.talents.pending.nextBlockGainMultiplier = nil
            }
        }
        nextEvent(
            kind: .effect(.shieldApplied),
            source: .init(source),
            abilityID: abilityID, abilityName: abilityName,
            target: target,
            amount: applied,
            keyword: .block,
            origin: origin,
        )
        CombatTriggerEngine.afterBlockGained(applied, by: target, in: &self)
        return applied
    }

    private mutating func adjustedBlockGain(_ amount: Int, to target: Combatant) -> (Int, Bool) {
        let triggers = modifiers(for: target.id).triggers
        let belowHalf = roster.isBelowHalfHealth(for: target)
        let healthMultiplier = belowHalf ? triggers.blockGainBelowHalfMultiplier : 1
        let pending = roster.runtime(for: target)?.talents.pending
        let prepared = pending?.nextBlockGainMultiplier?.availableValue(
            cardSerial: resolution.cardTalents?.playSerial, actionID: resolution.actionID,
        )
        let spendsPreparation = prepared != nil
        let multiplier = healthMultiplier * (prepared ?? 1)
        return (CombatRounding.scaled(amount, multiplier: multiplier), spendsPreparation)
    }

    mutating func interceptDebuff(_ effect: Effect, on target: Combatant) -> Bool {
        if CombatTriggerEngine.preventsDebuff(effect, on: target, in: self) {
            return true
        }
        guard effect.isRemovableDebuff,
              modifiers(for: target.id).triggers.blockFirstDebuffPerTurn,
              roster.runtime(for: target)?.talents.turn.blockedFaeWard != true
        else { return false }
        roster.mutateRuntime(for: target) { $0.talents.turn.blockedFaeWard = true }
        return true
    }

    @discardableResult
    mutating func insertEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int,
        at index: Int? = nil,
        replacing matches: (Effect) -> Bool = { _ in false },
    ) -> Bool {
        guard roster.participant(for: target) != nil,
              !CombatTriggerEngine.preventsPurgedEffect(effect, on: target, in: self),
              !interceptDebuff(effect, on: target) else { return false }
        let effectID = consumeNextEffectID()
        let activeEffect = ActiveEffect(
            id: effectID,
            effect: effect,
            remainingTurns: remainingTurns,
            sourceActorID: sourceID,
        )
        roster.mutateRuntime(for: target) { runtime in
            runtime.activeEffects.removeAll { matches($0.effect) }
            if let index {
                runtime.activeEffects.insert(activeEffect, at: index)
            } else {
                runtime.activeEffects.append(activeEffect)
            }
        }
        return true
    }
}
