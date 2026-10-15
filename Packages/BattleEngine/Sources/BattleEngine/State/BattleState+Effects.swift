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

    func adjustedOutgoingEffect(_ effect: Effect, sourceID: String) -> Effect {
        let profile = modifiers(for: sourceID)
        switch effect {
        case let .shield(keyword, buffer):
            return .shield(
                keyword, CombatRounding.scaled(
                    SaturatedArithmetic.saturatingAdd(buffer, profile.blockGainedBonus),
                    multiplier: 1 + profile.blockGainedPercent,
                ),
            )
        default:
            return effect
        }
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
        guard roster.health(for: target) > 0 else { return 0 }
        if CombatTriggerEngine.frozenTargetCannotBlockOrHeal(target, in: self)
            || CombatTriggerEngine.preventsPurgedEffect(.shield(.block, amount), on: target, in: self) {
            return 0
        }
        let (keyword, buffer): (Keyword, Int)
        if amountBasis == .base,
           case let .shield(kw, buf) = adjustedOutgoingEffect(.shield(.block, amount), sourceID: source.id) {
            (keyword, buffer) = (kw, buf)
        } else {
            (keyword, buffer) = (.block, amount)
        }
        let (adjustedBuffer, spendsPreparation) = amountBasis == .base
            ? adjustedBlockGain(buffer, to: target) : (buffer, false)
        let applied = DefensePoolEngine.add(
            adjustedBuffer,
            to: target,
            keyword: keyword,
            sourceActorID: source.id,
            applyFightPacing: amountBasis == .base,
            in: &self,
        )
        if applied > 0, spendsPreparation {
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
            keyword: keyword,
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
        guard !CombatTriggerEngine.preventsPurgedEffect(effect, on: target, in: self),
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

    /// @discardableResult so existing fire-and-forget callers are untouched;
    /// new callers (like TimedDebuffHandler) should check the return instead
    /// of assuming the effect landed (ward/purge interception can refuse it).
    @discardableResult
    mutating func appendEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String,
        remainingTurns: Int,
    ) -> Bool {
        insertEffect(
            effect,
            to: target,
            sourceID: sourceID,
            remainingTurns: remainingTurns,
        )
    }

    @discardableResult
    mutating func prependEffect(
        _ effect: Effect,
        to target: Combatant,
        sourceID: String? = nil,
        remainingTurns: Int,
    ) -> Bool {
        insertEffect(
            effect,
            to: target,
            sourceID: sourceID,
            remainingTurns: remainingTurns,
            at: 0,
        )
    }
}
